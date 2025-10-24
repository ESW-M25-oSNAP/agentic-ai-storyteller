#!/bin/bash

# Build and deployment script for Checkpoint 2

echo "=== Building Android Agent for Checkpoint 2 ==="

# Check if we're in the correct directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found. Please run this script from the networking directory."
    exit 1
fi

# Check if ANDROID_NDK is set
if [ -z "$ANDROID_NDK" ]; then
    echo "Error: ANDROID_NDK environment variable not set."
    echo "Please set it to your Android NDK path, e.g.:"
    echo "export ANDROID_NDK=/path/to/android-ndk"
    exit 1
fi

echo "Building agent..."
mkdir -p build
cd build

# Configure cmake
cmake .. -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
         -DANDROID_ABI=arm64-v8a \
         -DANDROID_PLATFORM=android-21

# Build
make

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Binary location: $(pwd)/agent"
    
    echo ""
    echo "To deploy to Android device:"
    echo "1. Make sure ADB is connected: adb devices"
    echo "2. Push the agent: adb push agent /data/local/tmp/"
    echo "3. Make executable: adb shell chmod +x /data/local/tmp/agent"  
    echo "4. Run agent: adb shell '/data/local/tmp/agent A <LAPTOP_IP> 8080'"
    echo ""
    echo "Replace <LAPTOP_IP> with your laptop's IP address."
    echo "Use 'A' for device A (has NPU), 'B' for device B (no NPU)"
    
else
    echo "Build failed!"
    exit 1
fi