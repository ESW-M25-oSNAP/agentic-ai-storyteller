#!/bin/bash

PROJECT_DIR="$HOME/ESW/agentic-ai-storyteller/networking"
NDK_PATH="$HOME/ESW/agentic-ai-storyteller/android-ndk-r27d-linux"
ORCHESTRATOR_IP="172.20.10.3"
PORT="8080"
DEVICE_A_SERIAL="60e0c72f"
DEVICE_B_SERIAL="RZCT90P1WAK"

# Check prerequisites
if ! command -v adb &> /dev/null; then
    echo "ADB not found. Install it: sudo apt-get install android-tools-adb"
    exit 1
fi
if [ ! -f "$NDK_PATH/build/cmake/android.toolchain.cmake" ]; then
    echo "NDK not found at $NDK_PATH"
    exit 1
fi

# Check device authorization
for SERIAL in "$DEVICE_A_SERIAL" "$DEVICE_B_SERIAL"; do
    if adb devices | grep "$SERIAL" | grep -q "unauthorized"; then
        echo "Device $SERIAL is unauthorized. Enable USB Debugging and allow on device."
        exit 1
    fi
done

# Build
cd "$PROJECT_DIR/build"
cmake .. -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21
make

# Deploy
echo "Deploying agent to devices..."
adb -s "$DEVICE_A_SERIAL" push agent /data/local/tmp
adb -s "$DEVICE_B_SERIAL" push agent /data/local/tmp
adb -s "$DEVICE_A_SERIAL" shell chmod +x /data/local/tmp/agent
adb -s "$DEVICE_B_SERIAL" shell chmod +x /data/local/tmp/agent
adb -s "$DEVICE_A_SERIAL" shell mkdir -p /storage/emulated/0/Pictures
adb -s "$DEVICE_A_SERIAL" push "$PROJECT_DIR/src/test.jpg" /storage/emulated/0/Pictures/test.jpg || echo "Warning: Failed to push test.jpg"

# Start orchestrator and devices
echo "Starting orchestrator..."
bash -c "cd $PROJECT_DIR; source venv/bin/activate; python3 orchestrator.py > orchestrator.log 2>&1" &

sleep 2
echo "Starting Device A..."
adb -s "$DEVICE_A_SERIAL" shell "/data/local/tmp/agent A $ORCHESTRATOR_IP $PORT" &

echo "Starting Device B..."
adb -s "$DEVICE_B_SERIAL" shell "/data/local/tmp/agent B $ORCHESTRATOR_IP $PORT" &

echo "Starting log monitors..."
bash -c "adb -s $DEVICE_A_SERIAL logcat | grep DeviceClient" &
bash -c "adb -s $DEVICE_B_SERIAL logcat | grep DeviceClient" &

echo "System started. Check orchestrator.log and device logs."