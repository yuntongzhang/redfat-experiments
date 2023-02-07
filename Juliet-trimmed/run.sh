#!/bin/bash

CASE_DIR=$PWD/CWE122_Heap_Based_Buffer_Overflow

REDFAT_DIR=/home/yuntong/fyp-sem2/lowfat.bin.tmp/new/
REDFAT_BIN=$REDFAT_DIR/lowfat.bin
LOWFAT_RUNTIME=$REDFAT_DIR/liblowfat.so

# store undetected test cases
MISS_VAL=$PWD/missed-valgrind
MISS_RED=$PWD/missed-redfat
rm $MISS_VAL
rm $MISS_RED
touch $MISS_VAL
touch $MISS_RED

total=0
valgrind=0
redfat=0

# build programs
cd $CASE_DIR
make individuals

# start server
./server.sh &
SERVER=$!
for file in *connect_socket*.out; do
    ((total++))
    # valgrind
    valgrind --leak-check=no --undef-value-errors=no --exit-on-first-error=yes --error-exitcode=5 ./$file
    if [ $? -eq 5 ]
    then
        ((valgrind++))
    else
        echo $file >> $MISS_VAL
    fi
    # redfat
    cd $REDFAT_DIR
    $REDFAT_BIN -Xbase -Xreads -o $CASE_DIR/cur.redfat $CASE_DIR/$file >/dev/null
    cd $CASE_DIR
    LD_PRELOAD=$LOWFAT_RUNTIME ./cur.redfat
    if [ $? -eq 6 ]
    then
        ((redfat++))
    else
        echo $file >> $MISS_RED
    fi
done
# stop server
kill $SERVER


./client.sh &
CLIENT=$!
for file in *listen_socket*.out; do
    ((total++))
    # valgrind
    valgrind --leak-check=no --undef-value-errors=no --exit-on-first-error=yes --error-exitcode=5 ./$file
    if [ $? -eq 5 ]
    then
        ((valgrind++))
    else
        echo $file >> $MISS_VAL
    fi
    # redfat
    cd $REDFAT_DIR
    $REDFAT_BIN -Xbase -Xreads -o $CASE_DIR/cur.redfat $CASE_DIR/$file >/dev/null
    cd $CASE_DIR
    LD_PRELOAD=$LOWFAT_RUNTIME ./cur.redfat
    if [ $? -eq 6 ]
    then
        ((redfat++))
    else
        echo $file >> $MISS_RED
    fi
done
kill $CLIENT


for file in *rand*.out; do
    ((total++))
    # valgrind
    valgrind --leak-check=no --undef-value-errors=no --exit-on-first-error=yes --error-exitcode=5 ./$file
    if [ $? -eq 5 ]
    then
        ((valgrind++))
    else
        echo $file >> $MISS_VAL
    fi
    # redfat
    cd $REDFAT_DIR
    $REDFAT_BIN -Xbase -Xreads -o $CASE_DIR/cur.redfat $CASE_DIR/$file >/dev/null
    cd $CASE_DIR
    LD_PRELOAD=$LOWFAT_RUNTIME ./cur.redfat
    if [ $? -eq 6 ]
    then
        ((redfat++))
    else
        echo $file >> $MISS_RED
    fi
done


for file in *fscanf*.out *fgets*.out; do
    ((total++))
    # valgrind
    valgrind --leak-check=no --undef-value-errors=no --exit-on-first-error=yes --error-exitcode=5 ./$file < ./input
    if [ $? -eq 5 ]
    then
        ((valgrind++))
    else
        echo $file >> $MISS_VAL
    fi
    # redfat
    cd $REDFAT_DIR
    $REDFAT_BIN -Xbase -Xreads -o $CASE_DIR/cur.redfat $CASE_DIR/$file >/dev/null
    cd $CASE_DIR
    LD_PRELOAD=$LOWFAT_RUNTIME ./cur.redfat < ./input
    if [ $? -eq 6 ]
    then
        ((redfat++))
    else
        echo $file >> $MISS_RED
    fi
done

echo "Total # of test cases processed:" $total
echo "# detected by Valgrind:" $valgrind
echo "# detected by RedFat:" $redfat
