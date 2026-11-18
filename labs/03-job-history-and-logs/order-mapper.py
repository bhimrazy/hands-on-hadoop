#!/usr/bin/env python3
import sys

for line in sys.stdin:
    product, price = line.strip().split(",")
    print(f"{product}\t{float(price)}")
