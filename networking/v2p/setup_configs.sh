#!/bin/bash
# Setup script to configure device settings for mesh network
# Run this on your laptop to generate config files for each device

echo "========================================="
echo "Mesh Network Configuration Setup"
echo "========================================="
echo ""

# Get device information
read -p "Enter IP for DeviceA: " IP_A
read -p "Enter IP for DeviceB: " IP_B
read -p "Enter IP for DeviceC: " IP_C

# Ask whether each device has an NPU (manually set by the user)
read -p "Does DeviceA have an NPU? (y/n): " HAS_NPU_A
read -p "Does DeviceB have an NPU? (y/n): " HAS_NPU_B
read -p "Does DeviceC have an NPU? (y/n): " HAS_NPU_C

# Normalize to true/false (JSON booleans)
function to_bool() {
  local v="$1"
  v=$(echo "$v" | tr '[:upper:]' '[:lower:]')
  if [[ "$v" == "y" || "$v" == "yes" || "$v" == "true" || "$v" == "1" ]]; then
    echo true
  else
    echo false
  fi
}

HAS_NPU_A=$(to_bool "$HAS_NPU_A")
HAS_NPU_B=$(to_bool "$HAS_NPU_B")
HAS_NPU_C=$(to_bool "$HAS_NPU_C")

PORT=5000

echo ""
echo "Creating configuration files..."

# Create config for DeviceA
cat > device_a_config.json << EOF
{
  "device_name": "DeviceA",
  "listen_port": ${PORT},
  "has_npu": ${HAS_NPU_A},
  "peers": [
    {
      "name": "DeviceB",
      "ip": "${IP_B}",
      "port": ${PORT}
    },
    {
      "name": "DeviceC",
      "ip": "${IP_C}",
      "port": ${PORT}
    }
  ]
}
EOF

# Create config for DeviceB
cat > device_b_config.json << EOF
{
  "device_name": "DeviceB",
  "listen_port": ${PORT},
  "has_npu": ${HAS_NPU_B},
  "peers": [
    {
      "name": "DeviceA",
      "ip": "${IP_A}",
      "port": ${PORT}
    },
    {
      "name": "DeviceC",
      "ip": "${IP_C}",
      "port": ${PORT}
    }
  ]
}
EOF

# Create config for DeviceC
cat > device_c_config.json << EOF
{
  "device_name": "DeviceC",
  "listen_port": ${PORT},
  "has_npu": ${HAS_NPU_C},
  "peers": [
    {
      "name": "DeviceA",
      "ip": "${IP_A}",
      "port": ${PORT}
    },
    {
      "name": "DeviceB",
      "ip": "${IP_B}",
      "port": ${PORT}
    }
  ]
}
EOF

echo "✓ Created device_a_config.json (DeviceA: ${IP_A})  has_npu=${HAS_NPU_A}"
echo "✓ Created device_b_config.json (DeviceB: ${IP_B})  has_npu=${HAS_NPU_B}"
echo "✓ Created device_c_config.json (DeviceC: ${IP_C})  has_npu=${HAS_NPU_C}"
echo ""
echo "Configuration complete!"
echo ""
echo "Next steps:"
echo "1. Deploy mesh_node.py and config files to each device"
echo "2. Use deploy_to_devices.sh to automate deployment via ADB"
echo ""
