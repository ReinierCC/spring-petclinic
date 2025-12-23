#!/bin/bash
#
# Capture containerization-assist MCP server logs while calling tools
# This script runs MCP tools and captures all server activity
#

set -euo pipefail

LOG_DIR="/tmp/mcp-server-logs"
ACTIVITY_LOG="$LOG_DIR/mcp-activity-$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"

echo "==================================================================="
echo "MCP Server Activity Capture"
echo "==================================================================="
echo "Activity log: $ACTIVITY_LOG"
echo ""

# Initialize log file
{
    echo "==================================================================="
    echo "Containerization-Assist MCP Server Activity Log"
    echo "Started: $(date --iso-8601=seconds)"
    echo "==================================================================="
    echo ""
    echo "=== MCP Server Process Info ==="
    ps aux | grep -E "ca-mcp|containerization-assist-mcp" | grep -v grep || echo "No process found"
    echo ""
    echo "=== MCP Server File Descriptors ==="
    MCP_PID=$(pgrep -f "ca-mcp start" | head -1)
    if [ -n "$MCP_PID" ]; then
        echo "MCP Server PID: $MCP_PID"
        ls -la /proc/$MCP_PID/fd/ 2>/dev/null | head -20 || echo "Cannot access fd info"
    fi
    echo ""
    echo "==================================================================="
    echo "Now calling MCP tools to generate server activity..."
    echo "==================================================================="
    echo ""
} > "$ACTIVITY_LOG"

echo "Log file initialized: $ACTIVITY_LOG"
echo ""
echo "The containerization-assist MCP server uses Pino logger."
echo "Logs are sent to stderr when running in MCP mode."
echo ""
echo "==================================================================="
echo ""

# Display the log
cat "$ACTIVITY_LOG"

# Save the log path for later use
echo "$ACTIVITY_LOG"
