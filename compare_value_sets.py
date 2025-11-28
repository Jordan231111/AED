#!/usr/bin/env python3
"""Compare numeric values between unique pointer dump and item manifest."""

from __future__ import annotations

import argparse
import pathlib
import re
from typing import Iterable, Sequence, Set

VALUE_PATTERN = re.compile(r"\(value\s+(\d+)\)")
TRAILING_NUMBER_PATTERN = re.compile(r"(\d+)\s*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Compare the value fields from the unique pointer dump against the "
            "item manifest and flag mismatches."
        )
    )
    parser.add_argument(
        "--unique-file",
        type=pathlib.Path,
        default=pathlib.Path("unique_pointer_dump.txt"),
        help="Path to the file that contains lines with '(value <number>)' segments.",
    )
    parser.add_argument(
        "--items-file",
        type=pathlib.Path,
        default=pathlib.Path("7huibjgkll.txt"),
        help="Path to the file that contains '::number' entries.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=50,
        help="Maximum entries to display in the console (0 = all).",
    )
    parser.add_argument(
        "--output-file",
        type=pathlib.Path,
        default=pathlib.Path("comparison_report.txt"),
        help="Where to write the complete results with one value per line.",
    )
    return parser.parse_args()


def read_unique_values(path: pathlib.Path) -> Set[int]:
    values: Set[int] = set()
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            match = VALUE_PATTERN.search(line)
            if match:
                values.add(int(match.group(1)))
    return values


def read_manifest_values(path: pathlib.Path) -> Set[int]:
    values: Set[int] = set()
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            match = TRAILING_NUMBER_PATTERN.search(line)
            if match:
                values.add(int(match.group(1)))
    return values


def section(name: str, numbers: Sequence[int], limit: int) -> None:
    numbers = sorted(numbers)
    print(f"\n{name}: {len(numbers)}")
    if not numbers:
        print("  (none)")
        return
    show_all = limit <= 0 or len(numbers) <= limit
    to_show = numbers if show_all else numbers[:limit]
    print(" ", ", ".join(str(num) for num in to_show))
    if not show_all:
        print(f"  ... ({len(numbers) - limit} more)")


def write_report(
    path: pathlib.Path,
    unique_count: int,
    manifest_count: int,
    missing: Sequence[int],
    critical: Sequence[int],
) -> None:
    lines = [
        f"Loaded {unique_count} unique-pointer values.\n",
        f"Loaded {manifest_count} manifest values.\n",
        "\n",
        f"Missing in manifest: {len(missing)}\n",
    ]
    if missing:
        lines.extend(f"{num}\n" for num in missing)
    else:
        lines.append("(none)\n")

    lines.extend(
        [
            "\n",
            f"Critical error: manifest-only entries: {len(critical)}\n",
        ]
    )
    if critical:
        lines.extend(f"{num}\n" for num in critical)
    else:
        lines.append("(none)\n")

    path.write_text("".join(lines), encoding="utf-8")
    print(f"\nFull report written to {path.resolve()}")


def main() -> None:
    args = parse_args()
    unique_values = read_unique_values(args.unique_file)
    manifest_values = read_manifest_values(args.items_file)

    missing_in_manifest = sorted(unique_values - manifest_values)
    critical_manifest_only = sorted(manifest_values - unique_values)

    print(f"Loaded {len(unique_values)} unique-pointer values.")
    print(f"Loaded {len(manifest_values)} manifest values.")

    section("Missing in manifest", missing_in_manifest, args.limit)
    section("Critical error: manifest-only entries", critical_manifest_only, args.limit)

    write_report(
        args.output_file,
        len(unique_values),
        len(manifest_values),
        missing_in_manifest,
        critical_manifest_only,
    )


if __name__ == "__main__":
    main()

