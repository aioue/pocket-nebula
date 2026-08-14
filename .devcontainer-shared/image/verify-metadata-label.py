#!/usr/bin/env python3
"""Verify the published base image carries a usable devcontainer.metadata label.

The entire inheritance mechanism depends on this label: it is what the dev
containers spec merges with each consumer's devcontainer.json, standing in for
the `extends` the spec still does not have. If the label is missing or malformed
the merge silently does nothing and every consumer quietly loses its shared
mounts, extensions and lifecycle hooks - with no error anywhere.

That failure is invisible at build time, so it is checked explicitly in CI
rather than discovered on someone's next rebuild.

Accepts either shape, so the same check works in CI and against a local build:

    docker buildx imagetools inspect TAG --format '{{ json .Image }}' | verify-metadata-label.py
    docker image inspect TAG --format '{{ json .Config.Labels }}'     | verify-metadata-label.py
"""
import json
import sys

REQUIRED_KEYS = ("customizations", "mounts", "containerEnv", "remoteUser")
LABEL = "devcontainer.metadata"


def label_sets(data):
    """Return each image's label map, tolerating the several inspect shapes.

    buildx imagetools on a multi-arch tag returns platform -> image config;
    on a single image it returns the config directly; and `docker image inspect
    --format '{{ json .Config.Labels }}'` returns a bare label map.
    """
    # Bare label map, e.g. {"devcontainer.metadata": "[...]"}
    if isinstance(data, dict) and LABEL in data:
        return [data]
    # Single image config, e.g. {"config": {"Labels": {...}}}
    if isinstance(data, dict) and "config" in data:
        return [(data.get("config") or {}).get("Labels") or {}]
    # Multi-arch: platform -> image config
    if isinstance(data, dict):
        return [(v.get("config") or {}).get("Labels") or {}
                for v in data.values() if isinstance(v, dict)]
    return []


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"FAIL: could not parse inspect output as JSON: {exc}", file=sys.stderr)
        return 1
    # An image with no labels at all inspects as JSON null.
    if data is None:
        print(f"FAIL: image has no labels, so no {LABEL}", file=sys.stderr)
        return 1

    all_labels = label_sets(data)
    if not all_labels:
        print("FAIL: inspect returned no image configs", file=sys.stderr)
        return 1

    for name, labels in enumerate(all_labels):
        raw = labels.get(LABEL)
        if not raw:
            print(f"FAIL: image[{name}] has no devcontainer.metadata label", file=sys.stderr)
            return 1
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as exc:
            print(f"FAIL: image[{name}] devcontainer.metadata is not valid JSON: {exc}", file=sys.stderr)
            return 1
        if not isinstance(parsed, list) or not parsed:
            print(f"FAIL: image[{name}] devcontainer.metadata must be a non-empty array", file=sys.stderr)
            return 1
        # The array carries one object per contributing layer - inherited
        # feature ids, the parent's remoteUser, then ours - so a required key may
        # legitimately live in any entry, not just the first.
        present = set().union(*(e.keys() for e in parsed if isinstance(e, dict)))
        missing = [k for k in REQUIRED_KEYS if k not in present]
        if missing:
            print(f"FAIL: image[{name}] devcontainer.metadata missing {missing}", file=sys.stderr)
            return 1

    print(f"OK: devcontainer.metadata present and valid on {len(all_labels)} image config(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
