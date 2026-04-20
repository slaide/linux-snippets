#!/usr/bin/env python3
"""Rewrite unpushed commit messages.

Strips trailer/body lines matching a regex (default: Co-Authored-By and
Claude/Anthropic mentions) and optionally compresses paragraph bodies into
bullet lists.
"""
from __future__ import annotations

import argparse
import difflib
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

if os.getenv("R_SCRIPT_GETHELP"):
    print("r rewrite-commits - Strip Claude/Co-Authored-By from unpushed commits")
    sys.exit(0)

DEFAULT_PATTERN = r"co-authored|claude|anthropic"
BULLET_RE = re.compile(r"^\s*([-*\u2022]|\d+[.)])\s+")


def run(cmd: list[str], *, check: bool = True) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        sys.exit(f"error: {' '.join(cmd)}\n{result.stderr.strip()}")
    return result.stdout.strip()


def detect_upstream() -> str:
    upstream = run(
        ["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
        check=False,
    )
    if not upstream:
        sys.exit(
            "error: current branch has no upstream. pass --upstream <ref> "
            "(e.g. origin/main)."
        )
    return upstream


def list_commits(upstream: str) -> list[tuple[str, str]]:
    """Return [(hash, message), ...] oldest first."""
    sep_rec = "\x1e"
    sep_field = "\x1f"
    result = subprocess.run(
        [
            "git", "log", f"{upstream}..HEAD",
            f"--format=%H{sep_field}%B{sep_rec}", "--reverse",
        ],
        capture_output=True, text=True, check=True,
    )
    commits = []
    for record in result.stdout.split(sep_rec):
        record = record.strip("\n")
        if not record:
            continue
        h, msg = record.split(sep_field, 1)
        commits.append((h, msg))
    return commits


def rewrite(msg: str, pattern: re.Pattern[str], compress: bool) -> str:
    lines = msg.splitlines()
    filtered = [l for l in lines if not pattern.search(l)]
    while filtered and not filtered[-1].strip():
        filtered.pop()
    if not filtered:
        return msg

    title = filtered[0]
    body = filtered[1:]
    while body and not body[0].strip():
        body.pop(0)

    if not body:
        return title

    body_text = "\n".join(body)
    if compress and not any(BULLET_RE.match(l) for l in body):
        sentences = re.split(r"(?<=[.!])\s+", body_text.replace("\n", " "))
        sentences = [s.strip() for s in sentences if s.strip()]
        if len(sentences) > 1:
            return title + "\n\n" + "\n".join("- " + s for s in sentences)

    return title + "\n\n" + body_text


def print_diffs(rewrites: dict[str, tuple[str, str]]) -> None:
    """Print a git-style unified diff for each pending rewrite."""
    use_color = sys.stdout.isatty()
    red = "\x1b[31m" if use_color else ""
    grn = "\x1b[32m" if use_color else ""
    cyan = "\x1b[36m" if use_color else ""
    bold = "\x1b[1m" if use_color else ""
    rst = "\x1b[0m" if use_color else ""

    for h, (old, new) in rewrites.items():
        print(f"\n{bold}commit {h}{rst}")
        diff = difflib.unified_diff(
            old.splitlines(),
            new.splitlines(),
            fromfile="a/message",
            tofile="b/message",
            lineterm="",
        )
        for line in diff:
            if line.startswith("+++") or line.startswith("---"):
                print(f"{bold}{line}{rst}")
            elif line.startswith("@@"):
                print(f"{cyan}{line}{rst}")
            elif line.startswith("+"):
                print(f"{grn}{line}{rst}")
            elif line.startswith("-"):
                print(f"{red}{line}{rst}")
            else:
                print(line)


def build_sequence_editor(tmp: Path, rewrites: dict[str, tuple[str, str]]) -> Path:
    """Write a Python script that rewrites git's rebase todo file in-place.

    For every `pick <hash>` whose full hash is in `rewrites`, appends an
    `exec git commit --amend -F <msgfile>` line. Identifies commits by hash,
    not position — robust to reordering or extra commits from hooks.
    """
    editor = tmp / "sequence_editor.py"
    editor.write_text(
        "#!/usr/bin/env python3\n"
        "import re, sys\n"
        f"MSG_DIR = {str(tmp)!r}\n"
        f"HASHES = {list(rewrites)!r}\n"
        "todo = sys.argv[1]\n"
        "out = []\n"
        "for line in open(todo).read().splitlines():\n"
        "    out.append(line)\n"
        "    m = re.match(r'^(?:pick|p) ([0-9a-f]+)', line)\n"
        "    if not m:\n"
        "        continue\n"
        "    prefix = m.group(1)\n"
        "    full = next((h for h in HASHES if h.startswith(prefix)), None)\n"
        "    if full:\n"
        "        out.append(f'exec git commit --amend -F {MSG_DIR}/{full}')\n"
        "open(todo, 'w').write('\\n'.join(out) + '\\n')\n"
    )
    editor.chmod(0o755)
    return editor


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--upstream", help="upstream ref (default: autodetect @{u})")
    ap.add_argument(
        "--pattern", default=DEFAULT_PATTERN,
        help=f"regex of lines to drop, case-insensitive (default: {DEFAULT_PATTERN!r})",
    )
    ap.add_argument(
        "--no-compress", dest="compress", action="store_false",
        help="don't compress paragraph bodies into bullet lists",
    )
    ap.add_argument(
        "--dry-run", action="store_true",
        help="print planned rewrites without touching history",
    )
    args = ap.parse_args()

    upstream = args.upstream or detect_upstream()
    pattern = re.compile(args.pattern, re.IGNORECASE)

    commits = list_commits(upstream)
    if not commits:
        print(f"no commits between {upstream} and HEAD.")
        return 0

    rewrites: dict[str, tuple[str, str]] = {}
    for h, old in commits:
        new = rewrite(old, pattern, args.compress)
        if old.strip() != new.strip():
            rewrites[h] = (old, new)
            print(f"  {h[:7]}: {old.splitlines()[0]}")

    if not rewrites:
        print("nothing to rewrite.")
        return 0

    print(f"\n{len(rewrites)}/{len(commits)} commits will be rewritten.")

    if args.dry_run:
        print_diffs(rewrites)
        return 0

    with tempfile.TemporaryDirectory(prefix="rewrite-commits-") as tmp_str:
        tmp = Path(tmp_str)
        for h, (_, new) in rewrites.items():
            (tmp / h).write_text(new)

        editor = build_sequence_editor(tmp, rewrites)
        base = run(["git", "merge-base", upstream, "HEAD"])

        env = os.environ.copy()
        env["GIT_SEQUENCE_EDITOR"] = str(editor)

        print(f"\nrebasing onto {base[:7]}…")
        result = subprocess.run(["git", "rebase", "-i", base], env=env)
        if result.returncode != 0:
            print(
                "rebase failed. check `git status`; you may need to "
                "`git rebase --abort`.",
                file=sys.stderr,
            )
            return 1

    check = run(["git", "log", f"{upstream}..HEAD", "--format=%B"])
    if pattern.search(check):
        print("warning: pattern still matches somewhere in rewritten history.",
              file=sys.stderr)
        return 2

    print("clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
