#!/usr/bin/env python3
"""Compare two non-interlaced 8-bit PNG files without third-party packages."""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth(left: int, above: int, upper_left: int) -> int:
    prediction = left + above - upper_left
    left_distance = abs(prediction - left)
    above_distance = abs(prediction - above)
    upper_left_distance = abs(prediction - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    return above if above_distance <= upper_left_distance else upper_left


def read_png(path: Path) -> tuple[int, int, bytes]:
    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: not a PNG file")

    position = len(PNG_SIGNATURE)
    header: tuple[int, int, int, int, int, int, int] | None = None
    compressed = bytearray()
    while position < len(payload):
        length = struct.unpack(">I", payload[position : position + 4])[0]
        chunk_type = payload[position + 4 : position + 8]
        chunk_data = payload[position + 8 : position + 8 + length]
        position += 12 + length
        if chunk_type == b"IHDR":
            header = struct.unpack(">IIBBBBB", chunk_data)
        elif chunk_type == b"IDAT":
            compressed.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    if header is None:
        raise ValueError(f"{path}: missing IHDR")
    width, height, depth, color_type, compression, filtering, interlace = header
    if depth != 8 or compression != 0 or filtering != 0 or interlace != 0:
        raise ValueError(f"{path}: only non-interlaced 8-bit PNG is supported")
    channels_by_type = {0: 1, 2: 3, 4: 2, 6: 4}
    if color_type not in channels_by_type:
        raise ValueError(f"{path}: unsupported PNG color type {color_type}")
    channels = channels_by_type[color_type]
    row_size = width * channels
    decoded = zlib.decompress(bytes(compressed))
    expected_size = height * (row_size + 1)
    if len(decoded) != expected_size:
        raise ValueError(f"{path}: malformed image payload")

    rows: list[bytearray] = []
    cursor = 0
    for _ in range(height):
        filter_type = decoded[cursor]
        cursor += 1
        source = decoded[cursor : cursor + row_size]
        cursor += row_size
        current = bytearray(row_size)
        previous = rows[-1] if rows else bytearray(row_size)
        for index, raw_value in enumerate(source):
            left = current[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                reconstructed = raw_value
            elif filter_type == 1:
                reconstructed = raw_value + left
            elif filter_type == 2:
                reconstructed = raw_value + above
            elif filter_type == 3:
                reconstructed = raw_value + ((left + above) // 2)
            elif filter_type == 4:
                reconstructed = raw_value + _paeth(left, above, upper_left)
            else:
                raise ValueError(f"{path}: unsupported PNG filter {filter_type}")
            current[index] = reconstructed & 0xFF
        rows.append(current)

    rgba = bytearray(width * height * 4)
    destination = 0
    for row in rows:
        for pixel_start in range(0, len(row), channels):
            if color_type == 0:
                red = green = blue = row[pixel_start]
                alpha = 255
            elif color_type == 2:
                red, green, blue = row[pixel_start : pixel_start + 3]
                alpha = 255
            elif color_type == 4:
                red = green = blue = row[pixel_start]
                alpha = row[pixel_start + 1]
            else:
                red, green, blue, alpha = row[pixel_start : pixel_start + 4]
            rgba[destination : destination + 4] = bytes((red, green, blue, alpha))
            destination += 4
    return width, height, bytes(rgba)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--channel-tolerance", type=int, default=2)
    parser.add_argument("--max-different-ratio", type=float, default=0.001)
    arguments = parser.parse_args()

    try:
        baseline_width, baseline_height, baseline = read_png(arguments.baseline)
        candidate_width, candidate_height, candidate = read_png(arguments.candidate)
    except (OSError, ValueError, zlib.error) as error:
        print(f"FAIL: {error}")
        return 2

    if (baseline_width, baseline_height) != (candidate_width, candidate_height):
        print("FAIL: image size changed: "
              f"{baseline_width}x{baseline_height} -> "
              f"{candidate_width}x{candidate_height}")
        return 1

    different = 0
    maximum_delta = 0
    for index in range(0, len(baseline), 4):
        delta = max(abs(baseline[index + channel] - candidate[index + channel])
                    for channel in range(4))
        maximum_delta = max(maximum_delta, delta)
        if delta > arguments.channel_tolerance:
            different += 1
    total = baseline_width * baseline_height
    ratio = different / total if total else 0.0
    status = "PASS" if ratio <= arguments.max_different_ratio else "FAIL"
    print(f"{status}: {different}/{total} pixels differ "
          f"({ratio:.4%}); maximum channel delta {maximum_delta}")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
