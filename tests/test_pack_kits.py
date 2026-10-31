from pathlib import Path
import os
import subprocess
import tempfile
import unittest
import zipfile

from tools.pack_kits import pack_kits


class PackKitsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="xcshop-pack-kits-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git("init", "--quiet")
        self.output = self.repo / "kits.zip"

    def git(self, *args, data=None):
        return subprocess.run(
            ["git", "-C", str(self.repo), *args], input=data,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        ).stdout

    def write(self, name, data=b"kit data\n", track=True):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        if track:
            self.git("add", "--", name)
        return path

    def test_tracked_files_only_with_kits_root_and_exact_contents(self):
        files = {
            "kits/templates/alpha.xcshopT": b"template\r\n",
            "kits/materials/中文 空格.xcontent": "中文内容\n".encode(),
            "kits/.hidden": b"\x00\xff\x01",
            "kits/empty": b"",
        }
        for name, data in files.items():
            self.write(name, data)
        self.write(".gitignore", b"kits/private/\n")
        self.write("kits/private/local.xcontent", track=False)
        self.write("kits/untracked.txt", track=False)
        self.write("settings.json", track=False)
        self.assertEqual(pack_kits(self.repo, self.output), len(files))
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.namelist(), sorted(files))
            self.assertIsNone(archive.testzip())
            for name, data in files.items():
                self.assertEqual(archive.read(name), data)

    def test_reproducible_and_reacts_to_file_changes(self):
        source = self.write("kits/template.xcshopT")
        pack_kits(self.repo, self.output)
        first = self.output.read_bytes()
        os.utime(source, (1700000000, 1700000000))
        pack_kits(self.repo, self.output)
        self.assertEqual(self.output.read_bytes(), first)
        source.write_bytes(b"updated\n")
        pack_kits(self.repo, self.output)
        self.assertNotEqual(self.output.read_bytes(), first)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(archive.read("kits/template.xcshopT"), b"updated\n")

    def test_missing_input_preserves_previous_archive(self):
        source = self.write("kits/template.xcshopT")
        pack_kits(self.repo, self.output)
        first = self.output.read_bytes()
        source.unlink()
        with self.assertRaises(FileNotFoundError):
            pack_kits(self.repo, self.output)
        self.assertEqual(self.output.read_bytes(), first)
        self.assertEqual(list(self.repo.glob("*.zip")), [self.output])

    def test_empty_repository_fails_without_creating_archive(self):
        with self.assertRaisesRegex(ValueError, "No Git-tracked files"):
            pack_kits(self.repo, self.output)
        self.assertFalse(self.output.exists())

    def test_git_symlinks_are_rejected(self):
        blob = self.git("hash-object", "-w", "--stdin", data=b"../settings.json").decode().strip()
        self.git("update-index", "--add", "--cacheinfo", f"120000,{blob},kits/link")
        with self.assertRaisesRegex(ValueError, "links or submodules"):
            pack_kits(self.repo, self.output)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
