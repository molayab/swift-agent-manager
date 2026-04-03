#!/usr/bin/env python3
"""agent-manager installer

Installs agent-manager either by building from source (default) or by
downloading a pre-compiled binary from GitHub Releases.

Usage:
  python3 install.py                        Build from source (requires Swift)
  python3 install.py --binary               Download a pre-compiled binary
  python3 install.py --binary --version v1.2.0
  python3 install.py --global               Install to /usr/local/bin

Options:
  --binary            Download a pre-compiled binary from GitHub Releases
  --version <tag>     Pin to a specific release tag (requires --binary)
  --global            Install to /usr/local/bin instead of ./bin
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# quickinstall.py lives alongside this script and contains all shared
# utilities (colours, helpers, platform detection, GitHub API, download).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from quickinstall import (  # noqa: E402
    GITHUB_REPO,
    BOLD, RESET, GRAY, YELLOW,
    ok, warn, fail, info,
    detect_platform,
    fetch_release_metadata,
    download_binary,
    write_repo_config,
)

# Directory that contains this script (the cloned repo root).
SCRIPT_DIR = Path(__file__).resolve().parent


# ── Argument parsing ───────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="agent-manager installer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--binary",
        action="store_true",
        help="Download a pre-compiled binary from GitHub Releases",
    )
    parser.add_argument(
        "--version",
        default="latest",
        metavar="TAG",
        help="Pin to a specific release tag, e.g. v1.2.0 (requires --binary)",
    )
    parser.add_argument(
        "--global",
        dest="global_install",
        action="store_true",
        help="Install to /usr/local/bin instead of ./bin",
    )
    return parser.parse_args()


# ── Binary installation ────────────────────────────────────────────────────────

def copy_to_destination(src: Path, global_install: bool) -> None:
    """Copy the built/downloaded binary to its final destination."""
    global_bin = Path("/usr/local/bin")

    if global_install:
        dest = global_bin / "agent-manager"
        info(f"Installing to {BOLD}{dest}{RESET}")
        if os.access(global_bin, os.W_OK):
            shutil.copy2(src, dest)
            dest.chmod(0o755)
        else:
            warn(f"{global_bin} is not writable — using sudo")
            subprocess.run(["sudo", "cp", str(src), str(dest)], check=True)
            subprocess.run(["sudo", "chmod", "+x", str(dest)], check=True)
        write_repo_config(SCRIPT_DIR)
        ok(f"Installed.  Run: {BOLD}agent-manager{RESET}")
    else:
        bin_dir = SCRIPT_DIR / "bin"
        bin_dir.mkdir(exist_ok=True)
        dest = bin_dir / "agent-manager"
        shutil.copy2(src, dest)
        dest.chmod(0o755)
        write_repo_config(SCRIPT_DIR)
        ok(f"Installed.  Run: {BOLD}./bin/agent-manager{RESET}")
        info(f"Or add {BOLD}{bin_dir}{RESET} to your PATH to run as {BOLD}agent-manager{RESET}")


# ── Install from GitHub ────────────────────────────────────────────────────────

def install_from_github(version: str, global_install: bool) -> None:
    os_name, arch = detect_platform()
    asset_name = f"agent-manager-{os_name}-{arch}"

    print()
    print(f"{BOLD}Downloading agent-manager…{RESET}  {GRAY}{GITHUB_REPO}{RESET}")
    print()
    info("Fetching release metadata…")

    release = fetch_release_metadata(version)
    tag_name = release.get("tag_name", "?")

    download_url = next(
        (a["browser_download_url"] for a in release.get("assets", [])
         if a.get("name") == asset_name),
        "",
    )

    if not download_url:
        available = [a["name"] for a in release.get("assets", [])]
        detail = ""
        if available:
            detail = "\nAssets available in this release:\n  " + "\n  ".join(available)
        fail(
            f"No binary found for {BOLD}{asset_name}{RESET} in release "
            f"{BOLD}{tag_name}{RESET}.{detail}\n"
            f"Build from source instead: {BOLD}python3 install.py{RESET} (without --binary)"
        )

    info(f"Downloading {BOLD}{asset_name}{RESET}  {GRAY}@ {tag_name}{RESET}")

    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp_path = Path(tmp.name)

    try:
        download_binary(download_url, tmp_path)
        tmp_path.chmod(0o755)
        print()
        copy_to_destination(tmp_path, global_install)
    finally:
        tmp_path.unlink(missing_ok=True)


# ── Build from source ──────────────────────────────────────────────────────────

def install_from_source(global_install: bool) -> None:
    swift = shutil.which("swift")
    if not swift:
        fail(
            "swift not found in PATH.\n"
            f"Install the Swift toolchain from {BOLD}https://swift.org/download{RESET}\n"
            f"Or download a pre-compiled binary: {BOLD}python3 install.py --binary{RESET}"
        )
        return  # unreachable; satisfies type checker

    result = subprocess.run([swift, "--version"], capture_output=True, text=True)
    swift_version = result.stdout.splitlines()[0] if result.stdout else "unknown"

    print()
    print(f"{BOLD}Building agent-manager…{RESET}  {GRAY}{swift_version}{RESET}")
    print()

    # Stream build output indented for visual grouping.
    process = subprocess.Popen(
        [swift, "build", "-c", "release"],
        cwd=SCRIPT_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    for line in process.stdout or []:
        print("  " + line, end="")
    process.wait()

    if process.returncode != 0:
        fail("Build failed.")

    binary = SCRIPT_DIR / ".build" / "release" / "agent-manager"
    if not binary.exists():
        fail(f"Build succeeded but binary not found at {binary}")

    print()
    copy_to_destination(binary, global_install)


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()
    if args.binary:
        install_from_github(args.version, args.global_install)
    else:
        install_from_source(args.global_install)
    print()


if __name__ == "__main__":
    main()
