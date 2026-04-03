#!/usr/bin/env python3
"""agent-manager quick installer

Downloads a pre-compiled binary and creates a ready-to-use repo.
No Swift toolchain required.

Usage (one-liner):
  curl -fsSL https://raw.githubusercontent.com/molayab/swift-agent-manager/main/quickinstall.py | python3

With options:
  python3 quickinstall.py [--dir <path>] [--global] [--version <tag>]

Options:
  --dir <path>      Where to create the repo  (default: ~/.config/agent-manager/src)
  --global          Also install the binary to /usr/local/bin
  --version <tag>   Pin to a specific release tag (default: latest)
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

GITHUB_REPO = "molayab/swift-agent-manager"

GITIGNORE_CONTENT = """\
# Local binary (installed by quickinstall.py / install.py)
bin/

# macOS
.DS_Store

# Private skills and commands (local only, never committed)
skills/*.private/
commands/*.private.md
"""

# ── Terminal colours ───────────────────────────────────────────────────────────

if sys.stdout.isatty():
    BOLD   = "\033[1m"
    RESET  = "\033[0m"
    GREEN  = "\033[32m"
    YELLOW = "\033[33m"
    RED    = "\033[31m"
    BLUE   = "\033[34m"
    GRAY   = "\033[90m"
else:
    BOLD = RESET = GREEN = YELLOW = RED = BLUE = GRAY = ""


def ok(msg: str) -> None:
    print(f"{GREEN}✓{RESET} {msg}")


def warn(msg: str) -> None:
    print(f"{YELLOW}!{RESET} {msg}")


def fail(msg: str) -> None:
    print(f"{RED}✗{RESET} {msg}", file=sys.stderr)
    sys.exit(1)


def info(msg: str) -> None:
    print(f"{BLUE}i{RESET} {msg}")


# ── Argument parsing ───────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="agent-manager quick installer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--dir",
        default=str(Path.home() / ".config" / "agent-manager" / "src"),
        metavar="PATH",
        help="Where to create the repo (default: ~/.config/agent-manager/src)",
    )
    parser.add_argument(
        "--global",
        dest="global_install",
        action="store_true",
        help="Also install the binary to /usr/local/bin",
    )
    parser.add_argument(
        "--version",
        default="latest",
        metavar="TAG",
        help="Pin to a specific release tag (default: latest)",
    )
    return parser.parse_args()


# ── Platform detection ─────────────────────────────────────────────────────────

def detect_platform() -> tuple[str, str]:
    """Return (os_name, arch) matching GitHub release asset names."""
    system = platform.system()
    if system == "Darwin":
        os_name = "macos"
    elif system == "Linux":
        os_name = "linux"
    else:
        fail(f"Unsupported platform: {system}")
        raise SystemExit(1)  # unreachable; satisfies type checker
    arch = platform.machine()  # arm64 | x86_64
    return os_name, arch


# ── GitHub release fetching ────────────────────────────────────────────────────

def fetch_release_metadata(version: str) -> dict:
    if version == "latest":
        url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
    else:
        url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/tags/{version}"

    try:
        with urllib.request.urlopen(url) as response:
            return json.loads(response.read())
    except Exception as exc:
        fail(f"Could not fetch release metadata from GitHub: {exc}")
        raise SystemExit(1)  # unreachable; satisfies type checker


def find_download_url(release: dict, asset_name: str) -> tuple[str, str]:
    """Return (download_url, tag_name) for the named asset, or ("", tag_name) if not found."""
    tag_name = release.get("tag_name", "?")
    for asset in release.get("assets", []):
        if asset.get("name") == asset_name:
            return asset["browser_download_url"], tag_name
    return "", tag_name


# ── Binary download ────────────────────────────────────────────────────────────

def download_binary(url: str, dest: Path) -> None:
    def _progress(block_count: int, block_size: int, total_size: int) -> None:
        if total_size > 0:
            downloaded = min(block_count * block_size, total_size)
            percent = downloaded * 100 // total_size
            bar_len = 40
            filled = bar_len * downloaded // total_size
            bar = "█" * filled + "░" * (bar_len - filled)
            print(f"\r  [{bar}] {percent:3d}%", end="", flush=True)

    urllib.request.urlretrieve(url, dest, reporthook=_progress)
    print()  # newline after progress bar


# ── Repo structure ─────────────────────────────────────────────────────────────

def create_repo_structure(install_dir: Path) -> None:
    info(f"Creating repo at {BOLD}{install_dir}{RESET}")

    for subdir in ("skills", "commands", "bin"):
        (install_dir / subdir).mkdir(parents=True, exist_ok=True)

    gitignore = install_dir / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text(GITIGNORE_CONTENT)
        ok(f"Created  {GRAY}.gitignore{RESET}")

    if not (install_dir / ".git").exists():
        subprocess.run(["git", "-C", str(install_dir), "init", "-q"], check=True)
        subprocess.run(["git", "-C", str(install_dir), "add", ".gitignore"], check=True)
        subprocess.run(
            ["git", "-C", str(install_dir), "commit", "-q", "-m", "Initial commit"],
            check=True,
        )
        ok("Initialised git repository")


# ── Binary installation ────────────────────────────────────────────────────────

def install_binary(src: Path, install_dir: Path, global_install: bool) -> None:
    global_bin = Path("/usr/local/bin")

    local_dest = install_dir / "bin" / "agent-manager"
    shutil.copy2(src, local_dest)
    local_dest.chmod(0o755)

    if global_install:
        global_dest = global_bin / "agent-manager"
        if os.access(global_bin, os.W_OK):
            shutil.copy2(src, global_dest)
            global_dest.chmod(0o755)
        else:
            warn(f"{global_bin} is not writable — using sudo")
            subprocess.run(["sudo", "cp", str(src), str(global_dest)], check=True)
            subprocess.run(["sudo", "chmod", "+x", str(global_dest)], check=True)
        ok(f"Installed  {GRAY}{global_dest}{RESET}")


# ── Config ─────────────────────────────────────────────────────────────────────

def write_repo_config(install_dir: Path) -> None:
    config_dir = Path.home() / ".config" / "agent-manager"
    config_dir.mkdir(parents=True, exist_ok=True)
    (config_dir / "repo").write_text(str(install_dir))
    ok(f"Repo path saved to {BOLD}~/.config/agent-manager/repo{RESET}")


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()
    install_dir = Path(args.dir).expanduser().resolve()

    # Verify required tools are available
    if not shutil.which("git"):
        fail("git is required but was not found in PATH.")

    os_name, arch = detect_platform()
    asset_name = f"agent-manager-{os_name}-{arch}"

    print()
    print(f"{BOLD}agent-manager quick install{RESET}  {GRAY}{GITHUB_REPO}{RESET}")
    print()
    info("Fetching release metadata…")

    release = fetch_release_metadata(args.version)
    download_url, tag_name = find_download_url(release, asset_name)

    if not download_url:
        available = [a["name"] for a in release.get("assets", [])]
        detail = ""
        if available:
            detail = "\nAvailable assets:\n  " + "\n  ".join(available)
        fail(f"No binary found for {asset_name} in release {tag_name}.{detail}")

    info(f"Downloading {BOLD}{asset_name}{RESET}  {GRAY}@ {tag_name}{RESET}")

    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp_path = Path(tmp.name)

    try:
        download_binary(download_url, tmp_path)
        tmp_path.chmod(0o755)

        print()
        create_repo_structure(install_dir)
        install_binary(tmp_path, install_dir, args.global_install)
        ok(f"Installed  {GRAY}bin/agent-manager{RESET}  {GRAY}({tag_name}){RESET}")
        write_repo_config(install_dir)
    finally:
        tmp_path.unlink(missing_ok=True)

    print()
    print(f"{BOLD}Done!{RESET}  Your agent-manager repo is at {BOLD}{install_dir}{RESET}")
    print()

    if args.global_install:
        info(f"Run: {BOLD}agent-manager skill activate{RESET}")
    else:
        info(f"Add {BOLD}{install_dir / 'bin'}{RESET} to your PATH, or run directly:")
        info(f"  {BOLD}{install_dir / 'bin' / 'agent-manager'} skill activate{RESET}")

    info("To push to your own remote:")
    info(
        f"  cd ~/.config/agent-manager/src && "
        "git remote add origin <your-repo-url> && git push -u origin main"
    )
    print()


if __name__ == "__main__":
    main()
