#!/usr/bin/env python3
import sys

current, total = None, 0.0
for line in sys.stdin:
    product, value = line.rstrip("\n").split("\t")
    if product != current:
        if current is not None:
            print(f"{current}\t{total:.2f}")
        current, total = product, 0.0
    total += float(value)
if current is not None:
    print(f"{current}\t{total:.2f}")
