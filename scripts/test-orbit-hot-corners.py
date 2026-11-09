#!/usr/bin/env python3
"""Check live Orbit hot-corner coverage on the named Niri outputs.

Enable Orbit hot corners and leave the selected outputs outside fullscreen,
with no conflicting Niri overview corner, before running this check.
Example: python3 scripts/test-orbit-hot-corners.py HDMI-A-1 eDP-1
"""

import argparse
import collections
import json
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("outputs", nargs="+", help="Outputs that should have a hot corner")
    args = parser.parse_args()
    layers = json.loads(subprocess.check_output(["niri", "msg", "-j", "layers"], text=True))
    counts = collections.Counter(
        layer["output"] for layer in layers
        if layer["namespace"] == "quickshell:screenCorners"
    )
    missing = []
    for output in args.outputs:
        present = counts[output] > 0
        print(f"{'PASS' if present else 'FAIL'}: {output}: {counts[output]} corner surfaces")
        if not present:
            missing.append(output)
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
