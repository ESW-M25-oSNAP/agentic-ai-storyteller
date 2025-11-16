#!/bin/bash
# Quick verification script for Checkpoint 1
# Runs essential checks to confirm LinUCB solver is ready

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/device_scripts"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Checkpoint 1 - Quick Verification"
echo "========================================"
echo ""

# Check 1: Binary exists
echo -n "[1/6] Checking if binary exists... "
if [ -f "linucb_solver" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "Run: make test"
    exit 1
fi

# Check 2: Binary is executable
echo -n "[2/6] Checking if binary is executable... "
if [ -x "linucb_solver" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check 3: Can initialize
echo -n "[3/6] Testing initialization... "
./linucb_solver init verify_A.dat verify_B.dat 1.0 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check 4: Can calculate score
echo -n "[4/6] Testing score calculation... "
SCORE=$(./linucb_solver score verify_A.dat verify_B.dat 50 75 100 1.0 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$SCORE" ]; then
    echo -e "${GREEN}✓${NC} (score: $SCORE)"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check 5: Can train
echo -n "[5/6] Testing training... "
./linucb_solver train verify_A.dat verify_B.dat 50 75 100 7.5 1.0 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Check 6: Training affects scores
echo -n "[6/6] Verifying learning... "
SCORE_AFTER=$(./linucb_solver score verify_A.dat verify_B.dat 50 75 100 1.0 2>/dev/null)
if [ "$SCORE" != "$SCORE_AFTER" ]; then
    echo -e "${GREEN}✓${NC} (score changed to: $SCORE_AFTER)"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

# Cleanup
rm -f verify_A.dat verify_B.dat

echo ""
echo "========================================"
echo -e "${GREEN}All checks passed! ✓${NC}"
echo "========================================"
echo ""
echo "LinUCB Solver is ready for deployment."
echo ""
echo "Next steps:"
echo "  1. Checkpoint 2: Integrate with bid_listener.sh"
echo "  2. Checkpoint 3: Implement feedback loop"
echo ""
echo "Quick test commands:"
echo "  make test       # Run build tests"
echo "  ./test_linucb.sh  # Comprehensive test suite"
echo "  ./demo_linucb.sh  # Interactive demo"
