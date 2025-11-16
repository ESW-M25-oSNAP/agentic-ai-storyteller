#!/bin/bash
# Deploy lini binary to Android devices
# Usage: ./deploy_lini.sh [device_serial]

DEVICE=${1:-""}
BIN_PATH="/data/local/tmp"
LINI_BIN="lini"

echo "Deploying LinUCB solver (lini) to device..."
echo ""

if [ ! -f "$LINI_BIN" ]; then
    echo "Error: $LINI_BIN not found in current directory"
    echo "Build it first in Termux on the device:"
    echo "  clang -O2 -lm -o lini linucb_solver.c"
    exit 1
fi

# Push binary
if [ -n "$DEVICE" ]; then
    adb -s "$DEVICE" push "$LINI_BIN" "$BIN_PATH/"
    adb -s "$DEVICE" push "../linucb_A.dat" "../linucb_B.dat" "$BIN_PATH/"
    adb -s "$DEVICE" shell "chmod 755 $BIN_PATH/$LINI_BIN"
    adb -s "$DEVICE" shell "cd $BIN_PATH && ./$LINI_BIN init state_A.dat state_B.dat 1.0"
else
    adb push "$LINI_BIN" "$BIN_PATH/"
    adb -s "$DEVICE" push "../linucb_A.dat" "../linucb_B.dat" "$BIN_PATH/"
    adb shell "chmod 755 $BIN_PATH/$LINI_BIN"
    adb shell "cd $BIN_PATH && ./$LINI_BIN init state_A.dat state_B.dat 1.0"
fi

echo ""
echo "✓ Deployment complete!"
echo "Binary: $BIN_PATH/$LINI_BIN"
echo "State: $BIN_PATH/state_A.dat, state_B.dat"
