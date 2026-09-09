"""Exercise the real watcher against local repositories; never contact GitHub."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "modules/home/notes-git-watch.sh"


class NotesSyncTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = dict(os.environ)
        for key in list(self.env):
            if key.startswith(("GIT_", "NOTES_")):
                del self.env[key]
        self.env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        self.remote = self.root / "remote.git"
        self.git(self.root, "init", "--bare", "--initial-branch=main", str(self.remote))
        self.a = self.root / "a"
        self.git(self.root, "clone", str(self.remote), str(self.a))
        self.identity(self.a)
        (self.a / "notes.md").write_text("original\n")
        self.git(self.a, "add", ".")
        self.git(self.a, "commit", "-m", "Initial notes")
        self.git(self.a, "push", "-u", "origin", "main")
        self.b = self.root / "b"
        self.git(self.root, "clone", str(self.remote), str(self.b))
        self.identity(self.b)

    def git(self, cwd, *args):
        return subprocess.check_output(["git", "-C", str(cwd), *args],
                                       env=self.env, stderr=subprocess.PIPE, text=True).strip()

    def identity(self, repo):
        self.git(repo, "config", "user.name", "Notes Test")
        self.git(repo, "config", "user.email", "notes@example.invalid")

    def sync(self, repo, ok=True):
        env = self.env | {"NOTES_DIR": str(repo), "NOTES_REMOTE_URL": str(self.remote)}
        result = subprocess.run(["bash", str(SCRIPT), "--once"], env=env,
                                capture_output=True, text=True, timeout=25)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_two_machines_keep_changes_and_main_branch(self):
        (self.a / "a.md").write_text("from A\n")
        (self.b / "b.md").write_text("from B\n")
        self.sync(self.a)
        self.sync(self.b)
        self.sync(self.a)
        for repo in (self.a, self.b):
            self.assertEqual((repo / "a.md").read_text(), "from A\n")
            self.assertEqual((repo / "b.md").read_text(), "from B\n")
            self.assertEqual(self.git(repo, "branch", "--show-current"), "main")
            self.assertEqual(self.git(repo, "status", "--porcelain"), "")
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD"), self.git(self.b, "rev-parse", "HEAD"))

    def test_failed_push_is_retried_without_new_edits(self):
        hook = self.remote / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        (self.a / "notes.md").write_text("saved offline\n")
        self.sync(self.a, ok=False)
        pending = self.git(self.a, "rev-parse", "HEAD")
        self.assertNotEqual(pending, self.git(self.remote, "rev-parse", "main"))
        hook.unlink()
        self.sync(self.a)
        self.assertEqual(pending, self.git(self.remote, "rev-parse", "main"))

    def test_fetch_failure_still_saves_locally(self):
        unavailable = self.root / "offline.git"
        self.remote.rename(unavailable)
        try:
            (self.a / "notes.md").write_text("edited without network\n")
            self.sync(self.a, ok=False)
            self.assertEqual(self.git(self.a, "status", "--porcelain"), "")
        finally:
            unavailable.rename(self.remote)
        self.sync(self.a)
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD"), self.git(self.remote, "rev-parse", "main"))

    def test_conflict_preserves_both_versions_and_aborts_rebase(self):
        (self.a / "notes.md").write_text("A changed this line\n")
        (self.b / "notes.md").write_text("B changed this line\n")
        self.sync(self.a)
        remote_head = self.git(self.remote, "rev-parse", "main")
        self.sync(self.b, ok=False)
        self.assertEqual((self.b / "notes.md").read_text(), "B changed this line\n")
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), remote_head)
        self.assertEqual(self.git(self.b, "status", "--porcelain"), "")
        self.assertFalse((self.b / ".git/rebase-merge").exists())

    def test_missing_clone_is_not_initialized(self):
        missing = self.root / "missing"
        self.sync(missing, ok=False)
        self.assertFalse(missing.exists())

    def test_nested_directory_is_not_treated_as_notes_repo(self):
        nested = self.a / "nested"
        nested.mkdir()
        (nested / "keep.txt").write_text("untouched")
        before = self.git(self.a, "rev-parse", "HEAD")
        self.sync(nested, ok=False)
        self.assertEqual(before, self.git(self.a, "rev-parse", "HEAD"))

    def test_wrong_origin_is_not_rewritten(self):
        self.git(self.a, "remote", "set-url", "origin", "unexpected-local-path")
        (self.a / "new.md").write_text("do not stage")
        self.sync(self.a, ok=False)
        self.assertEqual(self.git(self.a, "remote", "get-url", "origin"), "unexpected-local-path")
        self.assertEqual(self.git(self.a, "diff", "--cached"), "")

    def test_missing_identity_waits_before_staging(self):
        self.git(self.a, "config", "--unset", "user.email")
        (self.a / "new.md").write_text("do not stage")
        self.sync(self.a, ok=False)
        self.assertEqual(self.git(self.a, "diff", "--cached"), "")

    def test_existing_merge_is_left_untouched(self):
        marker = self.a / ".git/MERGE_HEAD"
        marker.write_text(self.git(self.a, "rev-parse", "HEAD") + "\n")
        (self.a / "new.md").write_text("do not stage")
        self.sync(self.a, ok=False)
        self.assertTrue(marker.exists())
        self.assertEqual(self.git(self.a, "diff", "--cached"), "")

    def test_detached_head_is_left_untouched(self):
        self.git(self.a, "checkout", "--detach")
        (self.a / "new.md").write_text("do not stage")
        self.sync(self.a, ok=False)
        self.assertEqual(self.git(self.a, "branch", "--show-current"), "")
        self.assertEqual(self.git(self.a, "diff", "--cached"), "")

    def test_local_branch_can_track_differently_named_remote_branch(self):
        self.git(self.a, "branch", "-m", "laptop")
        (self.a / "new.md").write_text("track main")
        self.sync(self.a)
        self.assertEqual(self.git(self.a, "branch", "--show-current"), "laptop")
        self.assertEqual(self.git(self.remote, "branch", "--format=%(refname:short)"), "main")

    def test_timestamp_commit_and_no_empty_commits(self):
        (self.a / "notes.md").write_text("updated\n")
        self.sync(self.a)
        subject = self.git(self.a, "log", "-1", "--format=%s")
        self.assertRegex(subject, r"^Auto-save \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
        saved = self.git(self.a, "rev-parse", "HEAD")
        self.sync(self.a)
        self.assertEqual(self.git(self.a, "rev-parse", "HEAD"), saved)


if __name__ == "__main__":
    if not shutil.which("timeout"):
        raise SystemExit("GNU timeout (coreutils) must be on PATH")
    unittest.main()
