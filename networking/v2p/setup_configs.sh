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

PORT=5000

echo ""
echo "----------------------------------------"
echo "NPU Configuration"
echo "----------------------------------------"
echo ""

# Get NPU information for DeviceA
read -p "Does DeviceA have an NPU? (y/n): " HAS_NPU_A
if [[ "$HAS_NPU_A" == "y" || "$HAS_NPU_A" == "Y" ]]; then
    HAS_NPU_A_JSON="true"
    read -p "Is DeviceA's NPU currently free/available? (y/n): " FREE_NPU_A
    if [[ "$FREE_NPU_A" == "y" || "$FREE_NPU_A" == "Y" ]]; then
        FREE_NPU_A_JSON="true"
    else
        FREE_NPU_A_JSON="false"
    fi
else
    HAS_NPU_A_JSON="false"
    FREE_NPU_A_JSON="false"
fi

# Get NPU information for DeviceB
read -p "Does DeviceB have an NPU? (y/n): " HAS_NPU_B
if [[ "$HAS_NPU_B" == "y" || "$HAS_NPU_B" == "Y" ]]; then
    HAS_NPU_B_JSON="true"
    read -p "Is DeviceB's NPU currently free/available? (y/n): " FREE_NPU_B
    if [[ "$FREE_NPU_B" == "y" || "$FREE_NPU_B" == "Y" ]]; then
        FREE_NPU_B_JSON="true"
    else
        FREE_NPU_B_JSON="false"
    fi
else
    HAS_NPU_B_JSON="false"
    FREE_NPU_B_JSON="false"
fi

# Get NPU information for DeviceC
read -p "Does DeviceC have an NPU? (y/n): " HAS_NPU_C
if [[ "$HAS_NPU_C" == "y" || "$HAS_NPU_C" == "Y" ]]; then
    HAS_NPU_C_JSON="true"
    read -p "Is DeviceC's NPU currently free/available? (y/n): " FREE_NPU_C
    if [[ "$FREE_NPU_C" == "y" || "$FREE_NPU_C" == "Y" ]]; then
        FREE_NPU_C_JSON="true"
    else
        FREE_NPU_C_JSON="false"
    fi
else
    HAS_NPU_C_JSON="false"
    FREE_NPU_C_JSON="false"
fi

echo ""
echo "Creating configuration files..."

# Create config for DeviceA
cat > device_a_config.json << EOF
{
  "device_name": "DeviceA",
  "listen_port": ${PORT},
  "has_npu": ${HAS_NPU_A_JSON},
  "free_npu": ${FREE_NPU_A_JSON},
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
  "has_npu": ${HAS_NPU_B_JSON},
  "free_npu": ${FREE_NPU_B_JSON},
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
  "has_npu": ${HAS_NPU_C_JSON},
  "free_npu": ${FREE_NPU_C_JSON},
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

echo "✓ Created device_a_config.json (DeviceA: ${IP_A}, NPU: ${HAS_NPU_A_JSON}, Free: ${FREE_NPU_A_JSON})"
echo "✓ Created device_b_config.json (DeviceB: ${IP_B}, NPU: ${HAS_NPU_B_JSON}, Free: ${FREE_NPU_B_JSON})"
echo "✓ Created device_c_config.json (DeviceC: ${IP_C}, NPU: ${HAS_NPU_C_JSON}, Free: ${FREE_NPU_C_JSON})"
echo ""
echo "Configuration complete!"
echo ""
echo "Next steps:"
echo "1. Deploy mesh_node.py and config files to each device"
echo "2. Use deploy_to_devices.sh to automate deployment via ADB"
echo ""
