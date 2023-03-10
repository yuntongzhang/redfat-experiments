#!/bin/bash
#   _|                                      _|_|_|_|            _|
#   _|          _|_|    _|      _|      _|  _|        _|_|_|  _|_|_|_|
#   _|        _|    _|  _|      _|      _|  _|_|_|  _|    _|    _|
#   _|        _|    _|    _|  _|  _|  _|    _|      _|    _|    _|
#   _|_|_|_|    _|_|        _|      _|      _|        _|_|_|      _|_|
#
# All-in-one SPEC2006 handling script.
#
if [ -t 1 ]
then
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BOLD="\033[1m"
    OFF="\033[0m"
else
    RED=
    GREEN=
    YELLOW=
    BOLD=
    OFF=
fi

SPEC2006_PATH=$PWD/cpu2006

if [ ! -d "$SPEC2006_PATH" ]
then
    echo -e "${YELLOW}warning${OFF}: SPEC2006 installation is missing!"
    MOUNT_POINT=$PWD/mnt
    mkdir -p "$MOUNT_POINT"
    SPEC2006_ISO=$PWD/cpu2006-1.2.iso
    if [ -e "$SPEC2006_ISO" ]
    then
        echo -e "${GREEN}log${OFF}: attempting to install SPEC2006 from" \
            "$SPEC2006_ISO image file..."
        sudo mount --read-only -o loop "$SPEC2006_ISO" "$MOUNT_POINT"
    else
        echo -e "${GREEN}log${OFF}: attempting to install SPEC2006 from" \
            "/dev/cdrom..."
        sudo mount --read-only /dev/cdrom "$MOUNT_POINT"
    fi
    if [ ! -e "$MOUNT_POINT/Revisions" ]
    then
        echo -e "${RED}ERROR${OFF}: $MOUNT_POINT is not the SPEC2006-1.2" \
            "installation disk"
        sudo umount "$MOUNT_POINT"
        exit 1
    fi
    md5sum "$MOUNT_POINT/Revisions" > cpu2006.md5
    if ! grep "c625c2108d653f74e983484ae4bae760" cpu2006.md5 >/dev/null
    then
        echo -e "${RED}ERROR${OFF}: $MOUNT_POINT is not the SPEC2006-1.2" \
            "installation disk"
        sudo umount "$MOUNT_POINT"
        exit 1
    fi
    rm -f cpu2006.md5
    cd "$MOUNT_POINT"
    echo -e "${GREEN}log${OFF}: install SPEC2006..."
    ./install.sh -f -d "$SPEC2006_PATH"
    cd ..
    sudo umount "$MOUNT_POINT"
else
    echo -e "${GREEN}log${OFF}: using existing SPEC2006 installation" \
        "($SPEC2006_PATH)..."
fi

# if [ ! -e "$SPEC2006_PATH/lowfat.patched" ]
# then
#     echo -e "${GREEN}log${OFF}: applying SPEC2006 patch..."
#     SPEC2006_PATCH=cpu2006.patch
#     cd "$SPEC2006_PATH"
#     if ! patch -p0 < "../$SPEC2006_PATCH" > "lowfat.patched"
#     then
#         echo -e "${RED}ERROR${OFF}: failed to patch SPEC2006"
#         exit 1
#     fi
#     cd ..
# else
#     echo -e "${GREEN}log${OFF}: assuming the SPEC2006 patch is already" \
#         "applied..."
# fi

# unpatch
if [ -e "$SPEC2006_PATH/lowfat.patched" ]
then
    echo -e "${GREEN}log${OFF}: Unpatching SPEC2006..."
    SPEC2006_PATCH=cpu2006.patch
    cd "$SPEC2006_PATH"
    if ! patch -R -p0 < "../$SPEC2006_PATCH"
    then
        echo -e "${RED}ERROR${OFF}: failed to unpatch SPEC2006"
        exit 1
    fi
    rm "$SPEC2006_PATH/lowfat.patched"
    cd ..
else
    echo -e "${GREEN}log${OFF}: assuming the SPEC2006 is already unpatched..."
fi

CC_PATH=/usr/bin
REDFAT_PATH=$PWD/../../../fyp-sem2/redfat-release
BENCHMARKS_PATH=$SPEC2006_PATH/benchspec/CPU2006
cd "$SPEC2006_PATH"

##############################################################################
# Adapted from AddressSanitizer's SPEC2006 script:
# To run all C tests use all_c, for C++ use all_cpp. To run integer tests
# use int, for floating point use fp.
NAME=$1
shift

usage()
{
    PROG=`basename $0`
    echo -e "${RED}USAGE${OFF}: $PROG TAG BENCHMARKS"
    echo
    echo -e "${YELLOW}NOTE${OFF}:"
    echo -e "\t- TAG is an arbitrary word, e.g. \"TEST\""
    echo -e "\t- BENCHMARKS specifies which benchmarks to run.  Use \"all\"" \
        "for to run all."
    exit 1
}

ulimit -s 8092

SPEC_J=${SPEC_J:-4}
NUM_RUNS=${NUM_RUNS:-1}
#CC=$CC_PATH/clang
#CXX=$CC_PATH/clang++
CC=$CC_PATH/gcc
CXX=$CC_PATH/g++
FC=$CC_PATH/gfortran
if [ -z "$FC" ]
then
    FC=echo
fi

OPT_LEVEL="-O2"
GAMESS_OPT_LEVEL="-O1"
COMMON_FLAGS="-m64 -fPIE -fPIC"
CC="$CC -std=gnu89 $COMMON_FLAGS"
CXX="$CXX $COMMON_FLAGS"
FC="$FC $COMMON_FLAGS"
LDOPT="-pie"

# step (1) generate allowlist
GEN_NAME=${NAME}-GEN
cat << EOF > config/$GEN_NAME.cfg
ignore_errors = yes
tune          = base
ext           = $GEN_NAME
output_format = asc, Screen
reportable = 0
check_md5 = 0
teeout        = yes
teerunout     = yes
strict_rundir_verify = 0
makeflags = -j$SPEC_J

default=default=default=default:
CC  = $CC
CXX = $CXX
FC  = $FC
OPTIMIZE    = $OPT_LEVEL
PORTABILITY = -DSPEC_CPU_LP64
LDOPT       = $LDOPT
EXTRA_LIBS  = $EXTRA_LIBS

416.gamess=default=default=default:
OPTIMIZE    = $GAMESS_OPT_LEVEL

400.perlbench=default=default=default:
CPORTABILITY= -DSPEC_CPU_LINUX_X64

462.libquantum=default=default=default:
CPORTABILITY= -DSPEC_CPU_LINUX

483.xalancbmk=default=default=default:
CXXPORTABILITY= -DSPEC_CPU_LINUX -include string.h

447.dealII=default=default=default:
CXXPORTABILITY= -include string.h -include stdlib.h -include cstddef

481.wrf=default=default=default:
CPORTABILITY= -DSPEC_CPU_CASE_FLAG -DSPEC_CPU_LINUX
EOF
pwd
. shrc

# set up build directories
runspec -c $GEN_NAME -a build -I -l --size train -n $NUM_RUNS $@
# patch the executables
cd $BENCHMARKS_PATH
exe_dirs=$(find . -path "./*/exe" -type d)

for exe_dir in $exe_dirs
do
    cd $BENCHMARKS_PATH
    cd $exe_dir
    if [ -x *.${GEN_NAME} ]
    then
        exe=$(find . -name *.${GEN_NAME} -type f)
        exe_full=$BENCHMARKS_PATH/$exe_dir/$exe
        redfat_exe=$exe.redfat
        # currently lowfat.bin only works in its directory
        cd $REDFAT_PATH
        if ./redfat.bin -Xallowlist-gen -Xreads $exe_full | grep -C 9 "num_patched_T3"
        then
            echo -e "\n${GREEN}log${OFF}: Successfully patched the executable $exe_full\n"
            rm $exe_full
            mv $redfat_exe $exe_full
        else
            echo -e "\n${RED}ERROR${OFF}: Failed to patch the executable $exe_full\n"
        fi
    else
        continue
    fi
done

# run benchmarks
cd $SPEC2006_PATH
rm config/$GEN_NAME.*
cat << EOF > config/$GEN_NAME.cfg
ignore_errors = yes
tune          = base
ext           = $GEN_NAME
output_format = asc, Screen
reportable = 0
check_md5 = 0
teeout        = yes
teerunout     = yes
strict_rundir_verify = 0
makeflags = -j$SPEC_J
env_vars = 1

default=default=default=default:
EXTRA_LIBS = $EXTRA_LIBS
ENV_LD_PRELOAD = $REDFAT_PATH/liblowfat.so
EOF
pwd
. shrc

runspec --nobuild -c $GEN_NAME -a run -I -l --size train -n $NUM_RUNS $@


# step (2) do the real run with allowlist
RUN_NAME=${NAME}-RUN
cat << EOF > config/$RUN_NAME.cfg
ignore_errors = yes
tune          = base
ext           = $RUN_NAME
output_format = asc, Screen
reportable = 0
check_md5 = 0
teeout        = yes
teerunout     = yes
strict_rundir_verify = 0
makeflags = -j$SPEC_J

default=default=default=default:
CC  = $CC
CXX = $CXX
FC  = $FC
OPTIMIZE    = $OPT_LEVEL
PORTABILITY = -DSPEC_CPU_LP64
LDOPT       = $LDOPT
EXTRA_LIBS  = $EXTRA_LIBS

416.gamess=default=default=default:
OPTIMIZE    = $GAMESS_OPT_LEVEL

400.perlbench=default=default=default:
CPORTABILITY= -DSPEC_CPU_LINUX_X64

462.libquantum=default=default=default:
CPORTABILITY= -DSPEC_CPU_LINUX

483.xalancbmk=default=default=default:
CXXPORTABILITY= -DSPEC_CPU_LINUX -include string.h

447.dealII=default=default=default:
CXXPORTABILITY= -include string.h -include stdlib.h -include cstddef

481.wrf=default=default=default:
CPORTABILITY= -DSPEC_CPU_CASE_FLAG -DSPEC_CPU_LINUX
EOF
pwd
. shrc

# set up build directories
runspec -c $RUN_NAME -a build -I -l --size ref -n $NUM_RUNS $@
# patch the executables
cd $BENCHMARKS_PATH
exe_dirs=$(find . -path "./*/exe" -type d)

for exe_dir in $exe_dirs
do
    cd $BENCHMARKS_PATH
    cd $exe_dir
    if [ -x *.${RUN_NAME} ]
    then
        exe=$(find . -name *.${RUN_NAME} -type f)
        exe_full=$BENCHMARKS_PATH/$exe_dir/$exe
        redfat_exe=$exe.redfat
        # currently lowfat.bin only works in its directory
        cd $REDFAT_PATH
        if ./redfat.bin -P -Xallowlist -Oelim=true -Obatch=30 -Omerge=true -Xreads -Xlowfat $exe_full | grep -C 9 "num_patched_T3"
        then
            echo -e "\n${GREEN}log${OFF}: Successfully patched the executable $exe_full\n"
            rm $exe_full
            mv $redfat_exe $exe_full
        else
            echo -e "\n${RED}ERROR${OFF}: Failed to patch the executable $exe_full\n"
        fi
    else
        continue
    fi
done

# run benchmarks
cd $SPEC2006_PATH

rm config/$RUN_NAME.*
cat << EOF > config/$RUN_NAME.cfg
ignore_errors = yes
tune          = base
ext           = $RUN_NAME
output_format = asc, Screen
reportable = 0
check_md5 = 0
teeout        = yes
teerunout     = yes
strict_rundir_verify = 0
makeflags = -j$SPEC_J
env_vars = 1

default=default=default=default:
EXTRA_LIBS = $EXTRA_LIBS
ENV_LD_PRELOAD = $REDFAT_PATH/liblowfat.so
EOF
pwd
. shrc

runspec --nobuild -c $RUN_NAME -a run -I -l --size ref -n $NUM_RUNS $@
