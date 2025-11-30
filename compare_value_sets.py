#!/usr/bin/env python3
"""Compare numeric values between unique pointer dump and item manifest."""

from __future__ import annotations

import argparse
import pathlib
import re
from typing import Dict, Iterable, List, Sequence, Set

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
    parser.add_argument(
        "--error-file",
        type=pathlib.Path,
        default=pathlib.Path("error.txt"),
        help="Path to file whose numeric entries should be ignored entirely.",
    )
    parser.add_argument(
        "--hooks-file",
        type=pathlib.Path,
        default=pathlib.Path("AllTheItemHooksAE.txt"),
        help="Path to the hooks file containing 'ID -- Comment' mappings.",
    )
    return parser.parse_args()


def load_prefix_descriptions(path: pathlib.Path) -> Dict[str, str]:
    """Load prefix descriptions from the hooks file."""
    mapping: Dict[str, str] = {}
    if not path.exists():
        return mapping

    # Pattern to match "ID -- Comment"
    # Example: 297000001 -- light and shadow upgrade item??
    pattern = re.compile(r"^\s*(\d+)\s*--\s*(.*)")

    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            match = pattern.search(line)
            if match:
                full_id = match.group(1)
                comment = match.group(2).strip()
                
                # Clean up comments that might have trailing Lua syntax like "}, -- added 155"
                if "}," in comment:
                    comment = comment.split("},")[0].strip()
                # Remove trailing quotes if present (e.g. ending in ' or ")
                if comment.endswith('"') or comment.endswith("'"):
                    comment = comment[:-1].strip()
                
                # We use the first 4 digits as the prefix key
                if len(full_id) >= 4:
                    prefix = full_id[:4]
                    # If we have a collision, the last one read wins, or we could concatenate.
                    # For now, last one wins is simple and likely sufficient.
                    mapping[prefix] = comment
    return mapping


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


def read_error_values(path: pathlib.Path) -> Set[int]:
    if not path.exists():
        return set()
    values: Set[int] = set()
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                values.add(int(line))
            except ValueError:
                continue
    return values


def collect_prefixes(values: Sequence[int]) -> List[str]:
    seen: Set[str] = set()
    prefixes: List[str] = []
    for value in values:
        prefix = str(value)[:4]
        if prefix not in seen:
            prefixes.append(prefix)
            seen.add(prefix)
    return prefixes


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
    prefixes: Sequence[str],
    missing: Sequence[int],
    critical: Sequence[int],
    prefix_descriptions: Dict[str, str],
) -> None:
    lines = [
        "Prefixes (first 4 digits):\n",
    ]
    if prefixes:
        for prefix in prefixes:
            description = prefix_descriptions.get(prefix, "unknown category")
            lines.append(f"{prefix} -- {description}\n")
    else:
        lines.append("(none)\n")

    lines.extend(
        [
            "\n",
            f"Loaded {unique_count} unique-pointer values.\n",
            f"Loaded {manifest_count} manifest values.\n",
            "\n",
        ]
    )

    lines.extend(
        [
            f"Missing in manifest: {len(missing)}\n",
        ]
    )
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
    error_values = read_error_values(args.error_file)
    prefix_descriptions = load_prefix_descriptions(args.hooks_file)

    if error_values:
        unique_values.difference_update(error_values)
        manifest_values.difference_update(error_values)

    missing_in_manifest = sorted(unique_values - manifest_values)
    critical_manifest_only = sorted(manifest_values - unique_values)

    prefixes = collect_prefixes(missing_in_manifest)

    print(f"Loaded {len(unique_values)} unique-pointer values.")
    print(f"Loaded {len(manifest_values)} manifest values.")

    section("Missing in manifest", missing_in_manifest, args.limit)
    section("Critical error: manifest-only entries", critical_manifest_only, args.limit)

    write_report(
        args.output_file,
        len(unique_values),
        len(manifest_values),
        prefixes,
        missing_in_manifest,
        critical_manifest_only,
        prefix_descriptions,
    )


if __name__ == "__main__":
    main()

