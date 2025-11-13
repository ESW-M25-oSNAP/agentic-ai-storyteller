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
echo "Creating configuration files..."

# Create config for DeviceA
cat > device_a_config.json << EOF
{
  "device_name": "DeviceA",
  "listen_port": ${PORT},
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

echo "✓ Created device_a_config.json (DeviceA: ${IP_A})"
echo "✓ Created device_b_config.json (DeviceB: ${IP_B})"
echo "✓ Created device_c_config.json (DeviceC: ${IP_C})"
echo ""
echo "Configuration complete!"
echo ""
echo "Next steps:"
echo "1. Deploy mesh_node.py and config files to each device"
echo "2. Use deploy_to_devices.sh to automate deployment via ADB"
echo ""
