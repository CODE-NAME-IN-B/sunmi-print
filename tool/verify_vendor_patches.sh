#!/usr/bin/env bash
#
# Fails if a vendored package under third_party/ differs from its published
# source by anything other than the edits declared in
# third_party/vendor-patches.json.
#
# The point is to make an invisible dependency visible. A pub cache that has
# been hand patched builds on one machine and fails everywhere else, which is
# expensive to diagnose. Vendoring the patch in the repository makes the
# difference reviewable, and this script stops it quietly growing.
#
# Usage: tool/verify_vendor_patches.sh

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$root/third_party/vendor-patches.json"

if ! command -v python3 >/dev/null; then
  echo "python3 is required" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

status=0

packages="$(python3 -c '
import json, sys
print("\n".join(json.load(open(sys.argv[1]))))
' "$manifest")"

if [ -z "$packages" ]; then
  echo "No vendored packages declared in $manifest"
  exit 0
fi

while IFS= read -r package; do
  [ -n "$package" ] || continue
  echo "--- $package"
  published="$work/$package-published"
  vendored="$root/third_party/$package"

  if [ ! -d "$vendored" ]; then
    echo "FAIL $package: $vendored does not exist"
    status=1
    continue
  fi

  if ! python3 - "$manifest" "$package" "$work" "$published" <<'PY'
import hashlib, json, sys, urllib.request

manifest_path, package, work, published = sys.argv[1:5]
entry = json.load(open(manifest_path))[package]

url = f"https://pub.dev/api/archives/{package}-{entry['version']}.tar.gz"
with urllib.request.urlopen(url) as response:
    payload = response.read()

digest = hashlib.sha256(payload).hexdigest()
if digest != entry["sha256"]:
    sys.exit(
        f"FAIL {package}: published archive hash changed\n"
        f"     expected {entry['sha256']}\n"
        f"     actual   {digest}\n"
        f"     Re-check the patches in {manifest_path} against the new archive."
    )

import io, os, shutil, tarfile
with tarfile.open(fileobj=io.BytesIO(payload)) as tar:
    tar.extractall(published, filter="data")

# Anything the manifest says is not vendored is dropped from the comparison
# tree, so it cannot be mistaken for an unexplained difference.
for path in entry.get("remove_paths", []):
    shutil.rmtree(os.path.join(published, path), ignore_errors=True)
PY
  then
    status=1
    continue
  fi

  # Keep the vendored tree in step: anything the manifest says is deliberately
  # not vendored must not be sitting in third_party either.
  for path in $(python3 -c '
import json, sys
print(" ".join(json.load(open(sys.argv[1]))[sys.argv[2]].get("remove_paths", [])))
' "$manifest" "$package"); do
    rm -rf "${vendored:?}/$path"
  done

  # Compiling a vendored plugin writes its intermediates in place, so the tree
  # is not byte-for-byte clean between builds. Ignore those paths rather than
  # deleting them, so the next build stays incremental.
  for path in $(python3 -c '
import json, sys
print(" ".join(json.load(open(sys.argv[1]))[sys.argv[2]].get("ignore_paths", [])))
' "$manifest" "$package"); do
    rm -rf "${published:?}/$path" "${vendored:?}/$path"
  done

  if ! python3 - "$manifest" "$package" "$published" "$vendored" <<'PY'
import json, os, subprocess, sys

manifest_path, package, published, vendored = sys.argv[1:5]
entry = json.load(open(manifest_path))[package]
edits = {e["file"]: e for e in entry.get("edits", [])}

brief = subprocess.run(
    ["diff", "-r", "-q", published, vendored], capture_output=True, text=True
).stdout

differing, problems = [], []

for line in brief.splitlines():
    if line.startswith("Only in "):
        where, _, name = line[len("Only in "):].partition(": ")
        root = published if where.strip() == published else vendored
        rel = os.path.relpath(os.path.join(root, name), root)
        side = "missing from the vendored copy" if root == published else "not upstream"
        problems.append(rel)
        print(f"FAIL {package}: {rel} is {side}")
        continue

    if not (line.startswith("Files ") and line.endswith(" differ")):
        problems.append(line)
        print(f"FAIL $package: unrecognised diff output: {line}")
        continue

    upstream = line[len("Files "):].split(" and ")[0]
    differing.append(os.path.relpath(upstream, published))

for rel in differing:
    edit = edits.get(rel)
    if edit is None:
        problems.append(rel)
        print(
            f"FAIL {package}: {rel} differs from the published archive "
            f"but has no declared edit"
        )
        continue

    body = subprocess.run(
        ["diff", "-u", os.path.join(published, rel), os.path.join(vendored, rel)],
        capture_output=True, text=True,
    ).stdout.splitlines()

    removed = sum(1 for l in body if l.startswith("-") and not l.startswith("---"))
    added = sum(1 for l in body if l.startswith("+") and not l.startswith("+++"))
    expected = edit["find"].count("\n")

    if removed != expected or added != 0:
        problems.append(rel)
        print(
            f"FAIL {package}: {rel} removes {removed} and adds {added} line(s), but its "
            f"declared edit removes {expected} and adds none. Re-check the edit in "
            f"{manifest_path}."
        )

if not differing and not problems and edits:
    problems.append("stale-edits")
    print(
        f"FAIL {package}: identical to the published archive, but "
        f"{len(edits)} edit(s) are declared"
    )

if problems:
    sys.exit(1)

print(f"    {len(differing)} file(s) differ from upstream, all accounted for")
PY
  then
    status=1
  fi
done <<< "$packages"

if [ "$status" -ne 0 ]; then
  echo
  echo "Vendored patches have drifted. See third_party/README.md."
else
  echo
  echo "All vendored packages match their declared patches."
fi

exit "$status"
