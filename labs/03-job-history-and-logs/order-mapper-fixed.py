#!/usr/bin/env python3
import sys

for line in sys.stdin:
    product, price = line.strip().split(",")
    try:
        print(f"{product}\t{float(price)}")
    except ValueError:
        print(f"skipping bad row: {line.strip()}", file=sys.stderr)
