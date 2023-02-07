#!/usr/bin/python

import os

os.chdir("cpu2006/benchspec/CPU2006/482.sphinx3");

ref_file = open('allowlist-ref.txt', 'r')
ref_lines = ref_file.readlines()

train_file = open('allowlist-train.txt', 'r')
train_lines = train_file.readlines()

# set containing all the allowed checks from train workload
allowed_set = set(())

for line in train_lines:
    addr = line.split(" ")[0]
    is_allowed = line.split(" ")[1]
    if int(is_allowed) == 1:
        allowed_set.add(addr)

total_checks = 0
lowfat_checks = 0

for line in ref_lines:
    total_checks += 1
    addr = line.split(" ")[0]
    if addr in allowed_set:
        lowfat_checks += 1

print("Total # of checks: %d" % total_checks)
print("Total # of lowfat checks: %d" % lowfat_checks)

ref_file.close()
train_file.close()
