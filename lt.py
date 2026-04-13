#!/usr/bin/env python3
"""Tree listing with per-directory entry limit."""
import os, sys

LIMIT = 30
MAX_DEPTH = 2
IGNORE = {'.git', 'node_modules', '__pycache__', '.venv', '.mypy_cache', '.pytest_cache'}

def lt(path, prefix="", depth=0):
    if depth >= MAX_DEPTH:
        return
    try:
        entries = sorted(os.scandir(path), key=lambda e: (not e.is_dir(), e.name.lower()))
    except PermissionError:
        return
    entries = [e for e in entries if e.name not in IGNORE]
    total = len(entries)
    shown = entries[:LIMIT]
    for i, entry in enumerate(shown):
        is_last = (i == len(shown) - 1) and (total <= LIMIT)
        connector = "└── " if is_last else "├── "
        if entry.is_dir(follow_symlinks=False):
            print(f"{prefix}{connector}{entry.name}/")
            ext = "    " if is_last else "│   "
            lt(entry.path, prefix + ext, depth + 1)
        else:
            print(f"{prefix}{connector}{entry.name}")
    if total > LIMIT:
        print(f"{prefix}└── ... +{total - LIMIT} more")

root = sys.argv[1] if len(sys.argv) > 1 else "."
if len(sys.argv) > 2:
    MAX_DEPTH = int(sys.argv[2])
print(os.path.abspath(root))
lt(root)
