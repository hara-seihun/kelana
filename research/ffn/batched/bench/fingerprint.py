#!/usr/bin/env python3
"""Emit build-info.h: what this binary was built from, so a result file identifies its own sources.

argv[1] is the bonsai-halo checkout the deployed reference is lifted from; argv[2] is the
space-separated candidate source list the Makefile resolved.
"""
import hashlib
import os
import re
import subprocess
import sys


def git(repo, *args):
    try:
        return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True,
                              timeout=20).stdout.strip()
    except Exception:
        return ""


def source_closure(paths, include_dirs):
    """Hash local headers too: a candidate's implementation may live in an include."""
    pending = [os.path.normpath(p) for p in paths]
    seen = set()
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        try:
            with open(path) as f:
                text = f.read()
        except OSError:
            continue
        for name in re.findall(r'^\s*#\s*include\s*"([^"]+)"', text, re.MULTILINE):
            for directory in [os.path.dirname(path), *include_dirs]:
                target = os.path.normpath(os.path.join(directory, name))
                if os.path.isfile(target):
                    pending.append(target)
                    break
            else:
                raise RuntimeError(f"cannot fingerprint local include {name!r} from {path}")
    return seen


def sha_of(paths):
    h = hashlib.sha256()
    for p in sorted(paths):
        try:
            with open(p, "rb") as f:
                h.update(p.encode())
                h.update(f.read())
        except OSError:
            h.update(("missing:" + p).encode())
    return h.hexdigest()


here = os.path.dirname(os.path.abspath(__file__))
bonsai = sys.argv[1] if len(sys.argv) > 1 else "/path/to/workspace/projects/bonsai-halo"
cands = [c for c in (sys.argv[2].split() if len(sys.argv) > 2 else []) if c]

own = [os.path.join(here, f) for f in sorted(os.listdir(here))
       if f.endswith((".cpp", ".hip", ".h", ".hpp"))]
own += [os.path.join(here, "candidates", f)
        for f in sorted(os.listdir(os.path.join(here, "candidates")))] if os.path.isdir(os.path.join(here, "candidates")) else []
own.append(os.path.join(here, "..", "api.hpp"))
own.append(os.path.join(here, "..", "geometry.hpp"))

compiler = ""
try:
    compiler = subprocess.run(["hipcc", "--version"], capture_output=True, text=True,
                              timeout=20).stdout.splitlines()[1].strip()
except Exception:
    compiler = "unknown"

print('#pragma once')
print(f'#define KB_HARNESS_SHA256 "{sha_of(own)}"')
candidate_inputs = source_closure(cands, [here, os.path.dirname(here),
    os.path.join(bonsai, "src"), os.path.join(bonsai, "kernels")])
print(f'#define KB_CANDIDATE_SHA256 "{sha_of(candidate_inputs)}"')
print('#define KB_CANDIDATE_SOURCES "%s"' % " ".join(cands).replace('"', ''))
print(f'#define KB_KELANA_REVISION "{git(here, "rev-parse", "HEAD")}"')
print('#define KB_KELANA_DIRTY %s' % ("true" if git(here, "status", "--porcelain") else "false"))
print(f'#define KB_BONSAI_REVISION "{git(bonsai, "rev-parse", "HEAD")}"')
print('#define KB_COMPILER "%s"' % compiler.replace('"', "'"))
