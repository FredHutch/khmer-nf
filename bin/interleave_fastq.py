#!/usr/bin/env python3

import gzip
import os
import sys


def interleave(fp_r1, fp_r2, fpo):
    assert os.path.exists(fp_r1), fp_r1
    assert os.path.exists(fp_r2), fp_r2
    assert not os.path.exists(fpo), fpo

    r1_buffer = []
    r2_buffer = []

    print(f"Interleaving {fp_r1} and {fp_r2}, writing to {fpo}")

    with gzip.open(fp_r1, 'rt') as r1, gzip.open(fp_r2, 'rt') as r2, gzip.open(fpo, 'wt') as output:

        for (i, l1), l2 in zip(enumerate(r1), r2):

            if i > 0 and i % 100000 == 0:
                print(f"Processed {i:,} lines")

            if len(r1_buffer) == 4:
                for l in r1_buffer:
                    output.write(l)
                for l in r2_buffer:
                    output.write(l)
                r1_buffer = []
                r2_buffer = []

            if i % 4 == 0:
                r1_buffer.append(l1.rstrip("\n") + "/1\n")
                r2_buffer.append(l1.rstrip("\n") + "/2\n")
            elif i % 4 == 2:
                r1_buffer.append("+\n")
                r2_buffer.append("+\n")
            else:
                r1_buffer.append(l1)
                r2_buffer.append(l2)

        if len(r1_buffer) == 4:
            output.write(''.join(r1_buffer))
            output.write(''.join(r2_buffer))


if __name__ == "__main__":
    interleave(
        sys.argv[1],
        sys.argv[2],
        sys.argv[3]
    )
