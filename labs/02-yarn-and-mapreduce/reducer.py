#!/usr/bin/env python3
import sys

current, count = None, 0
for line in sys.stdin:
    word, value = line.rstrip("\n").split("\t")
    if word != current:
        if current is not None:
            print(f"{current}\t{count}")
        current, count = word, 0
    count += int(value)
if current is not None:
    print(f"{current}\t{count}")
