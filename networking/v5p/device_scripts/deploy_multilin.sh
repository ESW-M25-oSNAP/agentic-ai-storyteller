#!/bin/bash
# Deploy multilin binary and predictor to Android devices
# Usage: ./deploy_multilin.sh [device_serial]

DEVICE=${1:-""}
BIN_PATH="/data/local/tmp"
MULTILIN_BIN="multilin"
PREDICTOR_DIR="/data/local/tmp/cppllama-bundle/llama.cpp"

echo "========================================="
echo "Multi-LinUCB Solver Deployment"
echo "========================================="
echo ""

# Check if multilin binary exists
if [ ! -f "$MULTILIN_BIN" ]; then
    echo "❌ Error: $MULTILIN_BIN not found in current directory"
    echo ""
    echo "Build it first in Termux on the device:"
    echo "  1. adb push multi_linucb_solver.c /sdcard/"
    echo "  2. adb shell"
    echo "  3. In Termux: cd /sdcard"
    echo "  4. clang -O2 -lm -o multilin multi_linucb_solver.c"
    echo "  5. exit"
    echo "  6. adb pull /sdcard/multilin ."
    echo ""
    exit 1
fi

echo "Found multilin binary ✓"
echo ""

# Function to deploy to a single device
deploy_to_device() {
    local SERIAL=$1
    local DEVICE_NAME=$2
    
    echo "─────────────────────────────────────────"
    echo "Deploying to $DEVICE_NAME ($SERIAL)"
    echo "─────────────────────────────────────────"
    
    # Check device is connected
    if ! adb devices | grep -q "$SERIAL"; then
        echo "⚠️  Device not connected, skipping"
        return
    fi
    
    # 1. Push multilin binary
    echo "📦 Pushing multilin binary..."
    adb -s "$SERIAL" push "$MULTILIN_BIN" "$BIN_PATH/"
    adb -s "$SERIAL" shell "chmod 755 $BIN_PATH/$MULTILIN_BIN"
    
    # 2. Verify predictor exists
    echo "🔍 Checking for predictor..."
    PREDICTOR_EXISTS=$(adb -s "$SERIAL" shell "test -f $PREDICTOR_DIR/predictor && echo yes || echo no" | tr -d '\r')
    
    if [ "$PREDICTOR_EXISTS" = "yes" ]; then
        echo "✓ Predictor found at $PREDICTOR_DIR/predictor"
        
        # Verify LD_LIBRARY_PATH dependencies
        echo "🔍 Checking predictor dependencies..."
        adb -s "$SERIAL" shell "test -d $PREDICTOR_DIR/build/bin && echo yes || echo no" | grep -q "yes"
        if [ $? -eq 0 ]; then
            echo "✓ Predictor libraries found"
        else
            echo "⚠️  Warning: Predictor libraries not found at $PREDICTOR_DIR/build/bin"
            echo "   Make sure runtime.zip contents are deployed"
        fi
    else
        echo "⚠️  Warning: Predictor not found at $PREDICTOR_DIR/predictor"
        echo "   Deployment instructions:"
        echo "   1. Push predictor executable to device"
        echo "   2. adb -s $SERIAL push predictor $PREDICTOR_DIR/"
        echo "   3. adb -s $SERIAL push runtime/* $PREDICTOR_DIR/"
        echo "   4. adb -s $SERIAL shell chmod +x $PREDICTOR_DIR/predictor"
    fi
    
    # 3. Test multilin
    echo "🧪 Testing multilin..."
    TEST_OUTPUT=$(adb -s "$SERIAL" shell "$BIN_PATH/$MULTILIN_BIN score 50 60 100 75" 2>&1)
    if [ $? -eq 0 ]; then
        echo "✓ Multilin working: $TEST_OUTPUT"
    else
        echo "❌ Multilin test failed: $TEST_OUTPUT"
    fi
    
    echo "✓ Deployment complete for $DEVICE_NAME"
    echo ""
}

# Deploy to devices
if [ -n "$DEVICE" ]; then
    # Single device deployment
    deploy_to_device "$DEVICE" "Device"
else
    # Deploy to all known devices
    echo "Deploying to all devices..."
    echo ""
    
    # Device A (Pineapple)
    deploy_to_device "60e0c72f" "DeviceA-Pineapple"
    
    # Device B (Kalama)
    deploy_to_device "9688d142" "DeviceB-Kalama"
    
    # Device C
    deploy_to_device "ZD222LPWKD" "DeviceC"
fi

echo "========================================="
echo "✓ Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Verify deployment:"
echo "   adb shell ls -la $BIN_PATH/multilin"
echo "   adb shell ls -la $PREDICTOR_DIR/predictor"
echo ""
echo "2. Test multilin with predictor:"
echo "   adb shell \"$BIN_PATH/multilin score 50 60 100 'Hello world'\""
echo ""
echo "3. Start mesh network:"
echo "   cd .. && ./start_mesh.sh"
echo ""
