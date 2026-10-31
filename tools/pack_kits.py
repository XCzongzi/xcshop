"""Package Git-tracked kits into a reproducible ZIP, without third-party modules."""

import argparse
from pathlib import Path
import subprocess
import tempfile
import zipfile


def tracked_kit_files(repo: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), "ls-files", "--stage", "-z", "--", "kits/"],
        check=True, stdout=subprocess.PIPE,
    )
    paths = []
    for entry in result.stdout.split(b"\0"):
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, _, stage = metadata.split()
        path = raw_path.decode("utf-8")
        if stage != b"0" or mode not in (b"100644", b"100755"):
            raise ValueError(f"Cannot package conflicted files, links or submodules: {path}")
        paths.append(path)
    if not paths:
        raise ValueError("No Git-tracked files found in kits/.")
    return sorted(paths)


def pack_kits(repo: Path, output: Path) -> int:
    repo = repo.resolve()
    output = output.resolve()
    kits = repo / "kits"
    if output.is_relative_to(kits):
        raise ValueError("The output ZIP must be outside kits/.")
    paths = tracked_kit_files(repo)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Replace the old ZIP only after every input and the finished archive validate.
    with tempfile.NamedTemporaryFile(dir=output.parent, suffix=".zip", delete=False) as temp:
        temporary = Path(temp.name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name in paths:
                source = repo / name
                if source.is_symlink() or not source.resolve().is_relative_to(kits):
                    raise ValueError(f"Kit input must be a regular file inside kits/: {name}")
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, source.read_bytes(), compresslevel=9)
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip() is not None:
                raise ValueError("ZIP integrity check failed.")
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)
    return len(paths)


def main() -> None:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=repo / "kits.zip")
    args = parser.parse_args()
    count = pack_kits(repo, args.output)
    print(f"Packed {count} files into {args.output} ({args.output.stat().st_size} bytes).")


if __name__ == "__main__":
    main()
