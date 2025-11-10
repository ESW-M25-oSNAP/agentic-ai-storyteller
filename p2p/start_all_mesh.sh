#!/bin/bash
# Start all mesh listeners in separate terminal windows

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Starting all mesh listeners..."
echo ""

# Check if running in tmux
if [ -n "$TMUX" ]; then
    echo "Running in tmux - creating new panes..."
    
    # Split vertically for first device
    tmux split-window -h "$SCRIPT_DIR/start_mesh_A.sh"
    
    # Split horizontally for second device
    tmux split-window -v "$SCRIPT_DIR/start_mesh_B.sh"
    
    # Select first pane and split for third device
    tmux select-pane -t 0
    tmux split-window -v "$SCRIPT_DIR/start_mesh_C.sh"
    
    echo "✓ All listeners started in tmux panes"
else
    echo "Please run this in tmux or start manually:"
    echo ""
    echo "Terminal 1: ./start_mesh_A.sh"
    echo "Terminal 2: ./start_mesh_B.sh"
    echo "Terminal 3: ./start_mesh_C.sh"
fi
