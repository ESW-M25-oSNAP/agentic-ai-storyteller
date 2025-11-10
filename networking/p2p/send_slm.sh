#!/bin/bash
# Send SLM prompt from one device to another
# The target device will run Genie Bundle and return the result

if [ $# -lt 3 ]; then
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              SLM Prompt Sender (Genie Bundle)                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 <from_device> <to_device> <prompt>"
    echo ""
    echo "Devices: A, B, C"
    echo ""
    echo "Examples:"
    echo "  $0 A B 'Describe a beautiful sunset'"
    echo "  $0 A B 'Write a short poem about AI'"
    echo "  $0 C B 'Explain quantum computing in simple terms'"
    echo ""
    echo "What happens:"
    echo "  1. Device <from> sends SLM_PROMPT to Device <to>"
    echo "  2. Device <to> runs Genie Bundle with the prompt"
    echo "  3. Device <to> sends SLM_RESULT back to Device <from>"
    echo "  4. Watch the listener terminals to see the result!"
    echo ""
    exit 1
fi

FROM=$1
TO=$2
shift 2
PROMPT="$*"

# Get device serials
case $FROM in
    A) FROM_SERIAL="60e0c72f" ;;
    B) FROM_SERIAL="9688d142" ;;
    C) FROM_SERIAL="ZD222LPWKD" ;;
    *) echo "ERROR: Unknown device: $FROM"; exit 1 ;;
esac

TO_DEVICE="Device_$TO"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Sending SLM Prompt                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "From:   Device_$FROM"
echo "To:     $TO_DEVICE"
echo "Prompt: $PROMPT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Send the SLM prompt
adb -s $FROM_SERIAL shell "cd /data/local/tmp/mesh && sh mesh_sender.sh slm $TO_DEVICE '$PROMPT'"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ SLM prompt sent!"
echo ""
echo "What to watch:"
echo "  • Device $TO listener will show: [SLM] Received SLM prompt"
echo "  • Device $TO will execute Genie Bundle (may take 30s - 2 min)"
echo "  • Device $TO will send result back to Device $FROM"
echo "  • Device $FROM listener will show: [RESULT] SLM result from Device_$TO"
echo ""
echo "Tip: Run './monitor.sh' in another terminal to see real-time activity!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
