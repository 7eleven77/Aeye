#!/usr/bin/env python3
"""Render normalized arrow/box annotations onto an image using ImageMagick."""

import json
import math
import subprocess
import sys


def main():
    if len(sys.argv) < 3:
        sys.exit(0)
    image_path = sys.argv[1]
    raw_marks = sys.argv[2].strip()
    if not raw_marks or raw_marks == "[]":
        sys.exit(0)
    try:
        marks = json.loads(raw_marks)
    except json.JSONDecodeError:
        sys.exit(0)
    if not isinstance(marks, list) or not marks:
        sys.exit(0)

    dim_out = subprocess.check_output(
        ["magick", "identify", "-format", "%w %h", image_path],
        text=True,
    ).strip()
    parts = dim_out.split()
    if len(parts) < 2:
        sys.exit(0)
    width, height = float(parts[0]), float(parts[1])
    if width <= 0 or height <= 0:
        sys.exit(0)

    lw = max(3.0, min(width, height) * 0.0045)
    head = max(14.0, lw * 4.5)

    args = ["magick", image_path]

    def clamp01(v):
        return max(0.0, min(1.0, float(v)))

    for mark in marks:
        if not isinstance(mark, dict):
            continue
        kind = str(mark.get("kind") or "")
        x1 = clamp01(mark.get("x1", 0)) * width
        y1 = clamp01(mark.get("y1", 0)) * height
        x2 = clamp01(mark.get("x2", 0)) * width
        y2 = clamp01(mark.get("y2", 0)) * height

        if kind == "box":
            rx1, ry1 = min(x1, x2), min(y1, y2)
            rx2, ry2 = max(x1, x2), max(y1, y2)
            rect = f"rectangle {rx1:.1f},{ry1:.1f} {rx2:.1f},{ry2:.1f}"
            args += [
                "-fill", "none",
                "-stroke", "rgba(0,0,0,0.65)",
                "-strokewidth", f"{lw + 3:.1f}",
                "-draw", rect,
                "-stroke", "#d6ff4a",
                "-strokewidth", f"{lw:.1f}",
                "-draw", rect,
            ]
        elif kind == "arrow":
            angle = math.atan2(y2 - y1, x2 - x1)
            ax1 = x2 + head * math.cos(angle + 2.6)
            ay1 = y2 + head * math.sin(angle + 2.6)
            ax2 = x2 + head * math.cos(angle - 2.6)
            ay2 = y2 + head * math.sin(angle - 2.6)
            # Shorten shaft slightly so it meets the base of the arrowhead cleanly
            base_x = x2 + (head * 0.65) * math.cos(angle + math.pi)
            base_y = y2 + (head * 0.65) * math.sin(angle + math.pi)
            line_draw = f"line {x1:.1f},{y1:.1f} {base_x:.1f},{base_y:.1f}"
            poly_draw = f"polygon {x2:.1f},{y2:.1f} {ax1:.1f},{ay1:.1f} {ax2:.1f},{ay2:.1f}"
            args += [
                "-fill", "none",
                "-stroke", "rgba(0,0,0,0.65)",
                "-strokewidth", f"{lw + 3:.1f}",
                "-draw", line_draw,
                "-stroke", "#d6ff4a",
                "-strokewidth", f"{lw:.1f}",
                "-draw", line_draw,
                "-stroke", "rgba(0,0,0,0.65)",
                "-strokewidth", "2",
                "-fill", "#d6ff4a",
                "-draw", poly_draw,
            ]

    if len(args) > 2:
        args.append(image_path)
        subprocess.check_call(args)


if __name__ == "__main__":
    main()
