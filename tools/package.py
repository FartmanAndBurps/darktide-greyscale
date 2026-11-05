#!/usr/bin/env python3
"""Create an install ZIP using only Python's standard library; never deploy."""
from pathlib import Path
import argparse
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output-dir", type=Path, default=root / "dist",
                    help="output directory (default: repository dist/)")
args = parser.parse_args()
dist = args.output_dir
dist.mkdir(parents=True, exist_ok=True)
target = dist / "Darktide_Greyscale-v0.1.1.zip"
# Explicit allowlist: never include local backups, configs or development reports.
mod_files = [
    "Darktide_Greyscale.mod", "info.json",
    "scripts/mods/Darktide_Greyscale/Darktide_Greyscale.lua",
    "scripts/mods/Darktide_Greyscale/Darktide_Greyscale_data.lua",
    "scripts/mods/Darktide_Greyscale/Darktide_Greyscale_localization.lua",
]
sources = [(root / "mods/Darktide_Greyscale" / name, "Darktide_Greyscale/" + name)
           for name in mod_files]
sources += [(root / name, "Darktide_Greyscale/" + name) for name in
            ("README.md", "LICENSE", "docs/SOURCES.md", "docs/source-revisions.json")]
# Exclusive creation protects any previously built release.
with zipfile.ZipFile(target, "x", compression=zipfile.ZIP_DEFLATED) as archive:
    for source, name in sources:
        info = zipfile.ZipInfo(name, date_time=(2026, 11, 4, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, source.read_bytes())
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert set(names) == {name for _, name in sources}
    assert len(names) == len(sources)
    assert {Path(name).parts[0] for name in names} == {"Darktide_Greyscale"}
    assert "Darktide_Greyscale/Darktide_Greyscale.mod" in names
    for source, name in sources:
        assert archive.read(name) == source.read_bytes(), name
digest = hashlib.sha256(target.read_bytes()).hexdigest()
with (dist / "Darktide_Greyscale-v0.1.1.sha256").open("x") as output:
    output.write(f"{digest}  {target.name}\n")
print(f"Package PASS: {len(sources)} files; SHA256 {digest}")
