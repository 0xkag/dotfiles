#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class ThemeSample:
    name: str
    count: int = 3

    def render(self, active: bool) -> str:
        # TODO: check comments, strings, numbers, decorators, and operators.
        suffix = "active" if active else "idle"
        return f"{self.name}:{self.count}:{suffix}"


def compute_total(values: list[int]) -> int:
    total = 0
    for value in values:
        if value % 2 == 0:
            total += value * 2
        else:
            total -= value
    return total


if __name__ == "__main__":
    sample = ThemeSample("SearchTarget", count=7)
    print(sample.render(True))
    print(compute_total([1, 2, 3, 4]))
    print(Path("/tmp/theme-review"))
