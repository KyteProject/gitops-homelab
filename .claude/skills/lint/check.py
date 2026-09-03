#!/usr/bin/env python3
"""Structural checks for this GitOps repository.

Run from the repository root:  python3 .claude/skills/lint/check.py [scope]

`scope` is an optional path prefix, e.g. clusters/aeon/apps/media

Uses `yq` for YAML parsing because pyyaml is not installed on this machine.
Reports findings only. It never edits anything.
"""
import glob
import json
import os
import re
import subprocess
import sys

SCOPE = sys.argv[1] if len(sys.argv) > 1 else ""

CRITICAL, WARNING, INFO = "CRITICAL", "WARNING", "INFO"
findings = []


def report(level, msg):
    findings.append((level, msg))


def docs(path):
    """Every mapping document in a YAML file."""
    out = subprocess.run(
        ["yq", "-o=json", "-I0", "."], stdin=open(path), capture_output=True, text=True
    ).stdout
    result = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            parsed = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            result.append(parsed)
    return result


def in_scope(path):
    return not SCOPE or path.startswith(SCOPE)


KS_GLOBS = ["clusters/aeon/apps/*/*/ks.yaml", "infrastructure/controllers/*/*/ks.yaml"]
KUST_GLOBS = ["clusters/**/kustomization.yaml", "infrastructure/**/kustomization.yaml"]
APP_KUST_GLOBS = [
    "clusters/aeon/apps/*/*/*/kustomization.yaml",
    "infrastructure/controllers/*/*/*/kustomization.yaml",
]

ks_docs = [
    (p, d)
    for g in KS_GLOBS
    for p in sorted(glob.glob(g))
    if in_scope(p)
    for d in docs(p)
]

# ---------------------------------------------------------------- 1. references
for g in KUST_GLOBS:
    for path in sorted(glob.glob(g, recursive=True)):
        if not in_scope(path):
            continue
        parsed = docs(path)
        if not parsed:
            continue
        base = os.path.dirname(path)
        for key in ("resources", "components"):
            for ref in parsed[0].get(key) or []:
                if not isinstance(ref, str) or ref.startswith(("http://", "https://", "oci://")):
                    continue
                target = os.path.normpath(os.path.join(base, ref))
                if not os.path.exists(target):
                    report(CRITICAL, f"{path}: {key} entry does not exist: {ref}")

# ------------------------------------------------------- 2. ks paths and components
for path, doc in ks_docs:
    spec = doc.get("spec") or {}
    app_path = spec.get("path") or ""
    app_path = app_path[2:] if app_path.startswith("./") else app_path
    if not app_path:
        continue
    if not os.path.isdir(app_path):
        report(CRITICAL, f"{path}: spec.path does not exist: {app_path}")
        continue
    for component in spec.get("components") or []:
        # Component paths are relative to spec.path, not to the ks.yaml file.
        resolved = os.path.normpath(os.path.join(app_path, component))
        if not os.path.isdir(resolved):
            report(
                CRITICAL,
                f"{path}: component resolves to a missing directory: {component} -> {resolved}",
            )

# ------------------------------------------------------------- 3. substitutions
flux_vars = set()
for _, doc in ks_docs:
    flux_vars |= set(((doc.get("spec") or {}).get("postBuild") or {}).get("substitute") or {})

for path, doc in ks_docs:
    spec = doc.get("spec") or {}
    app_path = spec.get("path") or ""
    app_path = app_path[2:] if app_path.startswith("./") else app_path
    if not app_path or not os.path.isdir(app_path):
        continue
    defined = set((spec.get("postBuild") or {}).get("substitute") or {})
    used = set()
    for root, _, files in os.walk(app_path):
        for name in files:
            if not name.endswith((".yaml", ".yml")):
                continue
            text = open(os.path.join(root, name)).read()
            for match in re.finditer(r"\$\{([A-Z_][A-Z0-9_]*)(:=)?", text):
                if not match.group(2):  # no :=default
                    used.add(match.group(1))
    for var in sorted(used - defined):
        # Container commands legitimately contain runtime shell variables. Only flag
        # names that some ks in this repo substitutes, plus retired VolSync names.
        if var in flux_vars:
            report(
                CRITICAL,
                f"{path}: ${{{var}}} used in {app_path}/ with no default and no substitute",
            )

# --------------------------------------------------------------- 4. orphan files
for g in APP_KUST_GLOBS:
    for path in sorted(glob.glob(g)):
        if not in_scope(path):
            continue
        parsed = docs(path)
        if not parsed:
            continue
        base = os.path.dirname(path)
        listed = {
            os.path.normpath(os.path.join(base, r))
            for r in (parsed[0].get("resources") or [])
            if isinstance(r, str)
        }
        for f in sorted(glob.glob(os.path.join(base, "*.yaml"))):
            if os.path.basename(f) == "kustomization.yaml":
                continue
            if os.path.normpath(f) not in listed:
                report(INFO, f"{f}: on disk but not listed in {path}")

# ------------------------------------------------- 5. group kustomization coverage
for group_kust in sorted(glob.glob("clusters/aeon/apps/*/kustomization.yaml")):
    if not in_scope(group_kust):
        continue
    group_dir = os.path.dirname(group_kust)
    text = open(group_kust).read()
    for ks_path in sorted(glob.glob(os.path.join(group_dir, "*", "ks.yaml"))):
        entry = os.path.relpath(ks_path, group_dir)
        if entry in text:
            continue  # listed, whether active or commented out
        report(WARNING, f"{ks_path}: not referenced in {group_kust}, active or commented")

# ----------------------------------------------------------------- 6. leftovers
# VolSync is retired. Its API group and its postBuild variables are dead; the
# 1Password item is still called volsync-template, so match on structure only.
for pattern, note in (
    ("volsync.backube", "VolSync API group, the CRDs are gone"),
    (r"\${VOLSYNC_", "VolSync postBuild variable, never substituted now"),
):
    out = subprocess.run(
        ["grep", "-rn", "--include=*.yaml", pattern, "clusters", "infrastructure"],
        capture_output=True,
        text=True,
    ).stdout
    for line in out.splitlines():
        if in_scope(line.split(":", 1)[0]):
            report(CRITICAL, f"{line}  ({note})")

# -------------------------------------------------------------- 7. anti-patterns
def grep(pattern, *paths, flags=("-rn",)):
    out = subprocess.run(
        ["grep", *flags, "--include=*.yaml", pattern, *paths],
        capture_output=True,
        text=True,
    ).stdout
    return [l for l in out.splitlines() if in_scope(l.split(":", 1)[0])]

for hit in grep("kind: Ingress", "clusters", "infrastructure"):
    report(WARNING, f"{hit}  (this cluster routes with HTTPRoute through Envoy Gateway)")

for hit in grep(r"tag: latest", "clusters", "infrastructure"):
    report(
        WARNING,
        f"{hit}  (floating tag; a digest makes it immutable but the version is unreadable)",
    )

# A HelmRelease may use chart+HelmRepository instead of chartRef+OCIRepository, but
# the source it names has to exist.
# Sources live either in infrastructure/flux/repositories/ or, for most controllers,
# as a second document beside the HelmRelease itself.
SOURCE_KINDS = {"OCIRepository", "HelmRepository", "GitRepository"}
sources = set()
for f in glob.glob("clusters/**/*.yaml", recursive=True) + glob.glob(
    "infrastructure/**/*.yaml", recursive=True
):
    if os.path.basename(f) == "kustomization.yaml":
        continue
    head = open(f).read(4096)
    if not any(k in head for k in SOURCE_KINDS):
        continue
    for d in docs(f):
        if d.get("kind") in SOURCE_KINDS:
            name = (d.get("metadata") or {}).get("name")
            if name:
                sources.add(name)
for g in ("clusters/aeon/apps/*/*/app/*.yaml", "infrastructure/controllers/*/*/*/*.yaml"):
    for path in sorted(glob.glob(g)):
        if not in_scope(path):
            continue
        for d in docs(path):
            if d.get("kind") != "HelmRelease":
                continue
            spec = d.get("spec") or {}
            ref = spec.get("chartRef") or ((spec.get("chart") or {}).get("spec") or {}).get(
                "sourceRef"
            )
            name = (ref or {}).get("name")
            if name and name not in sources:
                report(
                    WARNING,
                    f"{path}: HelmRelease references source '{name}', which is not defined "
                    "in infrastructure/flux/repositories/",
                )

for path in sorted(glob.glob("clusters/aeon/apps/*/*/app/ocirepository.yaml")):
    if in_scope(path) and "app-template" in open(path).read():
        report(
            WARNING,
            f"{path}: per-app app-template OCIRepository, use the shared one in flux-system",
        )

# --------------------------------------------------------------------- output
order = {CRITICAL: 0, WARNING: 1, INFO: 2}
findings.sort(key=lambda f: (order[f[0]], f[1]))
current = None
for level, msg in findings:
    if level != current:
        current = level
        print(f"\n{level}")
        print("-" * len(level))
    print(f"  {msg}")
if not findings:
    print("No issues found.")
else:
    counts = {l: sum(1 for f in findings if f[0] == l) for l in (CRITICAL, WARNING, INFO)}
    print(f"\n{counts[CRITICAL]} critical, {counts[WARNING]} warning, {counts[INFO]} info")
