#!/bin/bash
# Live monitoring of all devices

DEVICES=(60e0c72f 9688d142 ZD222LPWKD)
LETTERS=(A B C)
COLORS=('\033[0;32m' '\033[0;34m' '\033[0;35m')
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Live Mesh Network Monitor                            ║"
echo "║           Press Ctrl+C to stop                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Tail all logs simultaneously
tail -f \
  >(adb -s 60e0c72f shell "tail -f /data/local/tmp/mesh/mesh_Device_A.log 2>/dev/null" | sed "s/^/[A] /" --unbuffered) \
  >(adb -s 9688d142 shell "tail -f /data/local/tmp/mesh/mesh_Device_B.log 2>/dev/null" | sed "s/^/[B] /" --unbuffered) \
  >(adb -s ZD222LPWKD shell "tail -f /data/local/tmp/mesh/mesh_Device_C.log 2>/dev/null" | sed "s/^/[C] /" --unbuffered) \
  2>/dev/null
