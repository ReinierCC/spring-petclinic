#!/bin/bash
#
# Monitor and log containerization-assist MCP server activity
# This script demonstrates how to capture MCP server logs
#

set -euo pipefail

LOG_DIR="/tmp/mcp-server-logs"
LOG_FILE="$LOG_DIR/ca-mcp-$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"

echo "==================================================================="
echo "MCP Server Log Monitoring Script"
echo "==================================================================="
echo "Log directory: $LOG_DIR"
echo "Log file: $LOG_FILE"
echo ""
echo "Current containerization-assist MCP server process:"
ps aux | grep -E "ca-mcp|containerization-assist-mcp" | grep -v grep || echo "No MCP server process found"
echo ""
echo "==================================================================="
echo ""

# Function to capture process information
capture_process_info() {
    echo "=== MCP Server Process Information ===" >> "$LOG_FILE"
    echo "Timestamp: $(date --iso-8601=seconds)" >> "$LOG_FILE"
    ps aux | grep -E "ca-mcp|containerization-assist-mcp" | grep -v grep >> "$LOG_FILE" 2>&1 || echo "No process found" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Function to capture environment
capture_environment() {
    echo "=== Environment Variables ===" >> "$LOG_FILE"
    env | grep -E "(LOG|DEBUG|MCP|CONTAINER)" | sort >> "$LOG_FILE" 2>&1 || echo "No relevant env vars" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Function to monitor system logs
monitor_system_logs() {
    echo "=== System Journal Logs (containerization-related) ===" >> "$LOG_FILE"
    journalctl --user -n 50 --no-pager 2>/dev/null | grep -i containerization >> "$LOG_FILE" 2>&1 || echo "No journal entries found" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Capture initial state
echo "Capturing initial MCP server state..."
capture_process_info
capture_environment

echo "==================================================================="
echo "Log file created: $LOG_FILE"
echo "==================================================================="
echo ""
echo "To view logs in real-time, run:"
echo "  tail -f $LOG_FILE"
echo ""
echo "MCP server logs are typically sent to stderr when running in MCP mode."
echo "The server uses Pino logger with LOG_LEVEL environment variable (default: info)."
echo ""
echo "To enable debug logging, restart the MCP server with:"
echo "  LOG_LEVEL=debug ca-mcp start"
echo ""
echo "==================================================================="

# Display the log file
cat "$LOG_FILE"
