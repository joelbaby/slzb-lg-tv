# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import unittest
from zipfile import ZIP_STORED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "dist" / "lg_tv.zip"


class InstallerTest(unittest.TestCase):
    def test_stored_flat_package_with_local_resources(self):
        self.assertLessEqual(INSTALLER.stat().st_size, 500_000)
        with ZipFile(INSTALLER) as bundle:
            names = bundle.namelist()
            self.assertEqual(names[0], "meta.json")
            self.assertEqual(set(names), {
                "meta.json", "app.be", "ui.html", "ui.css", "ui.js", "protocol.js", "tls.js",
                "README.md", "LICENSE", "bearssl-license.txt", "emscripten-license.txt",
                "musl-copyright.txt", "berry-example.js", "icon.png",
            })
            self.assertEqual(len(set(names)), len(names))
            for entry in bundle.infolist():
                self.assertEqual(entry.compress_type, ZIP_STORED)
                self.assertLessEqual(len(entry.filename.encode("utf-8")), 32)
                self.assertEqual(entry.filename, Path(entry.filename).name)
                self.assertGreater(entry.file_size, 0)
            self.assertIsNone(bundle.testzip())
            manifest = json.loads(bundle.read("meta.json"))
            self.assertEqual(manifest["folder"], "lg_tv")
            self.assertEqual(manifest["img"], "icon.png")
            self.assertTrue(bundle.read(manifest["img"]).startswith(b"\x89PNG\r\n\x1a\n"))
            self.assertEqual(manifest["permissions"], [])
            self.assertEqual(manifest["minFw"], "v3.4.5.dev1")
            self.assertEqual(manifest["models"], ["SLZB-MR4U"])
            self.assertFalse(manifest.get("dev", False))
            example = bundle.read("berry-example.js").decode("utf-8")
            self.assertEqual(
                json.loads(example.removeprefix("const LgBerryExample = ").removesuffix(";\n")),
                (ROOT / "examples" / "power_callbacks.be").read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
