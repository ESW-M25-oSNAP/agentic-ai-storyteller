#!/system/bin/sh
# wrapper_agent.sh
# Make this executable with chmod +x wrapper_agent.sh
# Usage: ./wrapper_agent.sh [mode] [query text]

AGENT_DIR="/data/local/tmp/agent-bundle"
KOTLIN_SCRIPT="$AGENT_DIR/agent.kts"

# Optional: make sure Termux Kotlin is in PATH
export PATH="$PATH:/data/data/com.termux/files/usr/bin"

# Run the Kotlin script with arguments passed to the wrapper
kotlinc -script "$KOTLIN_SCRIPT" "$@"

