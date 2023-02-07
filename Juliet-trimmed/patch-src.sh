#!/bin/bash

CASE_DIR=$PWD/CWE122_Heap_Based_Buffer_Overflow

cd $CASE_DIR

for file in *; do
    sed -i 's/sizeof(int));/sizeof(int));\n\t\tint * extra = (int *)malloc(10 * sizeof(int));\n\t\tprintIntLine(extra[5]);/' $file
done

for file in *; do
    sed -i 's/int\[10\];/int[10];\n\t\tint * extra = new int[10];\n\t\tprintIntLine(extra[5]);/' $file
done
