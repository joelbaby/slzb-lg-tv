#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import json
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "app"
DIST = ROOT / "dist"
INSTALLER = DIST / "lg_tv.zip"
LIMIT = 500_000

# Keep an explicit inventory so local config, test captures, and keys cannot be bundled.
FILES = (
    APP / "meta.json",
    APP / "icon.png",
    APP / "app.be",
    APP / "ui.html",
    APP / "ui.css",
    APP / "ui.js",
    APP / "protocol.js",
    APP / "README.md",
    DIST / "tls.js",
    DIST / "bearssl-license.txt",
    DIST / "emscripten-license.txt",
    DIST / "musl-copyright.txt",
    ROOT / "LICENSE",
)


def main():
    temporary = DIST / "lg_tv.tmp"
    try:
        with ZipFile(temporary, "w", compression=ZIP_STORED) as archive:
            for path in FILES:
                if len(path.name.encode("utf-8")) > 32:
                    raise ValueError(f"Installer filename too long: {path.name}")
                archive.writestr(ZipInfo(path.name), path.read_bytes())
            helper = (ROOT / "examples" / "power_callbacks.be").read_text(encoding="utf-8")
            script = f"const LgBerryExample = {json.dumps(helper)};\n"
            archive.writestr(ZipInfo("berry-example.js"), script.encode("utf-8"))
        size = temporary.stat().st_size
        if size > LIMIT:
            raise ValueError(f"Installer exceeds {LIMIT} bytes: {size}")
        temporary.replace(INSTALLER)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"{INSTALLER}: {size} bytes")


if __name__ == "__main__":
    main()
