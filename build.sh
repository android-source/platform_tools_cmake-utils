#!/bin/bash
# Expected arguments:
# $1 = out_dir
# $2 = dest_dir
# $3 = build_number

# exit on error
set -e

# calculate the root directory from the script path
# this script lives two directories down from the root
# tools/cmake-utils/build.sh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT_DIR"

function die() {
echo "$*" > /dev/stderr
    echo "Usage: $0 <out_dir> <dest_dir> <build_number>" > /dev/stderr
    exit 1
}

(($# > 3)) && die "[$0] Unknown parameter: $4"

OUT="$1"
DEST="$2"
BNUM="$3"

[ ! "$OUT"  ] && die "## Error: Missing out folder"
[ ! "$DEST" ] && die "## Error: Missing destination folder"
[ ! "$BNUM" ] && die "## Error: Missing build number"

mkdir -p "$OUT" "$DEST"
OUT="$(cd "$OUT" && pwd -P)"
DEST="$(cd "$DEST" && pwd -P)"

cat <<END_INFO
## Building android-studio ##
## Out Dir  : $OUT
## Dest Dir : $DEST
## Build Num: $BNUM

END_INFO

case "$(uname -s)" in
    Linux)  OS=linux;;
    Darwin) OS=darwin;;
    *_NT-*) OS=windows;;
esac

case "$OS" in
    windows)
        ROOT_DIR=$(cygpath -w "$ROOT_DIR")
        OUT=$(cygpath -w "$OUT")
        DEST=$(cygpath -w "$DEST")
        ;;
esac

SOURCE="$ROOT_DIR/external/cmake"
CMAKE_UTILS="$ROOT_DIR/tools/cmake-utils"
ANDROID_CMAKE="$ROOT_DIR/external/android-cmake"
PREBUILTS="$ROOT_DIR/prebuilts"
NINJA="$PREBUILTS/ninja/${OS}-x86/ninja"
CMAKE=("$PREBUILTS/cmake/${OS}-x86/bin/cmake")

BUILD="$OUT/cmake/build"
INSTALL="$OUT/cmake/install"
rm -rf "$BUILD" "$INSTALL"
mkdir -p "$BUILD" "$INSTALL"

# print commands for easier debugging
set -x

CONFIG=Release

case "$OS" in
    linux)
        TOOLCHAIN="$PREBUILTS/gcc/linux-x86/host/x86_64-linux-glibc2.15-4.8"
        CMAKE_OPTIONS+=(-DCMAKE_C_COMPILER="$TOOLCHAIN/bin/x86_64-linux-gcc")
        CMAKE_OPTIONS+=(-DCMAKE_CXX_COMPILER="$TOOLCHAIN/bin/x86_64-linux-g++")
        ;;
    darwin)
        ;;
    windows)
        CMAKE=(env PATH=$(cygpath --unix 'C:\Windows\System32')
               cmd /C "${VS120COMNTOOLS}VsDevCmd.bat" '&&'
               "${CMAKE[@]}")
        ;;
esac

CMAKE_OPTIONS+=(-G Ninja)
CMAKE_OPTIONS+=("$SOURCE")
CMAKE_OPTIONS+=(-DCMAKE_MAKE_PROGRAM="$NINJA")
CMAKE_OPTIONS+=(-DCMAKE_BUILD_TYPE=$CONFIG)
CMAKE_OPTIONS+=(-DCMAKE_INSTALL_PREFIX="$INSTALL")

(cd $BUILD && "${CMAKE[@]}" "${CMAKE_OPTIONS[@]}")
"${CMAKE[@]}" --build "$BUILD"
"${CMAKE[@]}" --build "$BUILD" --target test
"${CMAKE[@]}" --build "$BUILD" --target install

case "$OS" in
    windows)
        install "${NINJA}.exe" "$INSTALL/bin/"
        install "$CMAKE_UTILS/invoke_cmake.bat" "$INSTALL/"
        ;;
    *)
        install "$NINJA" "$INSTALL/bin/"
        install "$CMAKE_UTILS/invoke_cmake.sh" "$INSTALL/"
        ;;
esac
install "$ANDROID_CMAKE/android.toolchain.cmake" "$INSTALL/"

(cd "$INSTALL" && zip --symlinks -r "$DEST/cmake-${OS}-${BNUM}.zip" .)
