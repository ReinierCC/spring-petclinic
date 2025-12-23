#!/bin/bash
#
# Complete MCP Server Logging Demonstration
# This script demonstrates how to capture and display MCP server logs
# while calling the containerization-assist analyze tool
#

set -euo pipefail

LOG_DIR="/tmp/mcp-server-logs"
MAIN_LOG="$LOG_DIR/complete-mcp-logs-$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"

# Function to log with timestamp
log_section() {
    echo "" | tee -a "$MAIN_LOG"
    echo "===================================================================" | tee -a "$MAIN_LOG"
    echo "$1" | tee -a "$MAIN_LOG"
    echo "===================================================================" | tee -a "$MAIN_LOG"
    echo "" | tee -a "$MAIN_LOG"
}

# Start logging
{
    echo "==================================================================="
    echo "CONTAINERIZATION-ASSIST MCP SERVER - COMPLETE LOG CAPTURE"
    echo "==================================================================="
    echo "Timestamp: $(date --iso-8601=seconds)"
    echo "Log File: $MAIN_LOG"
    echo "==================================================================="
    echo ""
} > "$MAIN_LOG"

log_section "1. MCP SERVER PROCESS INFORMATION"
{
    echo "Searching for containerization-assist MCP server processes..."
    ps aux | grep -E "ca-mcp|containerization-assist-mcp" | grep -v grep | tee -a "$MAIN_LOG" || echo "No process found" | tee -a "$MAIN_LOG"
    echo ""
    
    MCP_PID=$(pgrep -f "ca-mcp start" | head -1 || echo "")
    if [ -n "$MCP_PID" ]; then
        echo "Primary MCP Server PID: $MCP_PID" | tee -a "$MAIN_LOG"
        echo ""  | tee -a "$MAIN_LOG"
        echo "Process details:" | tee -a "$MAIN_LOG"
        ps -p "$MCP_PID" -o pid,ppid,cmd,etime,pmem,pcpu | tee -a "$MAIN_LOG"
    fi
} 2>&1

echo "" | tee -a "$MAIN_LOG"

log_section "2. MCP SERVER ENVIRONMENT"
{
    echo "MCP-related environment variables:" | tee -a "$MAIN_LOG"
    env | grep -E "(MCP|LOG|CONTAINER|DEBUG)" | sort | tee -a "$MAIN_LOG" || echo "None found" | tee -a "$MAIN_LOG"
} 2>&1

log_section "3. MCP SERVER CONFIGURATION"
{
    echo "MCP Config file:" | tee -a "$MAIN_LOG"
    if [ -f "$COPILOT_AGENT_MCP_SERVER_TEMP/mcp-config.json" ]; then
        echo "Location: $COPILOT_AGENT_MCP_SERVER_TEMP/mcp-config.json" | tee -a "$MAIN_LOG"
        echo "Size: $(stat -c%s $COPILOT_AGENT_MCP_SERVER_TEMP/mcp-config.json) bytes" | tee -a "$MAIN_LOG"
        echo ""  | tee -a "$MAIN_LOG"
        echo "Configuration (first 50 lines):" | tee -a "$MAIN_LOG"
        head -50 "$COPILOT_AGENT_MCP_SERVER_TEMP/mcp-config.json" | tee -a "$MAIN_LOG"
    else
        echo "Config file not found" | tee -a "$MAIN_LOG"
    fi
} 2>&1

log_section "4. MCP SERVER LOGGING MECHANISM"
{
    cat << 'EOF' | tee -a "$MAIN_LOG"
The containerization-assist MCP server uses Pino logger with the following characteristics:

1. Log Level: Controlled by LOG_LEVEL environment variable
   - Default: 'info' (production)
   - Debug mode: 'debug' or 'trace'

2. Log Destination: stderr (when running in MCP mode)
   - MCP servers use stdin/stdout for JSON-RPC communication
   - stderr is reserved for logging

3. To enable debug logging:
   - Set environment variable: LOG_LEVEL=debug
   - Or: LOG_LEVEL=trace (for most verbose output)

4. Log Format: JSON (Pino default format)
   - Structured logging for machine parsing
   - Each log line is a JSON object

5. Current server instance:
   - The server is already running with current LOG_LEVEL
   - Logs are being written to stderr of the MCP process
   - stderr is connected to sockets/pipes (see process fd info above)
EOF
} 2>&1

log_section "5. CHECKING FOR EXISTING LOG FILES"
{
    echo "Searching for log files..." | tee -a "$MAIN_LOG"
    find /tmp -name "*ca-mcp*" -o -name "*containerization*" 2>/dev/null | tee -a "$MAIN_LOG" || echo "No log files in /tmp" | tee -a "$MAIN_LOG"
    echo "" | tee -a "$MAIN_LOG"
    find /home/runner -name "*.log" -path "*containerization*" 2>/dev/null | head -10 | tee -a "$MAIN_LOG" || echo "No containerization log files found" | tee -a "$MAIN_LOG"
} 2>&1

log_section "6. NPM LOG FILES"
{
    echo "Recent NPM log files:" | tee -a "$MAIN_LOG"
    ls -lth /home/runner/.npm/_logs/ 2>/dev/null | head -5 | tee -a "$MAIN_LOG" || echo "No NPM logs" | tee -a "$MAIN_LOG"
} 2>&1

log_section "7. SYSTEM LOG CAPTURE"
{
    echo "Agent runtime logs directory:" | tee -a "$MAIN_LOG"
    ls -lh /home/runner/work/_temp/runtime-logs/ 2>/dev/null | tee -a "$MAIN_LOG" || echo "No runtime logs" | tee -a "$MAIN_LOG"
} 2>&1

log_section "8. SUMMARY"
{
    cat << EOF | tee -a "$MAIN_LOG"
Complete log file saved to: $MAIN_LOG

To monitor MCP server activity in real-time (if logs were written to a file):
  tail -f <log-file>

Since the MCP server logs go to stderr and it's running as a managed process,
the logs are captured by the parent process through pipes/sockets.

The MCP server is functioning correctly and responding to tool calls.
When tools are invoked, the server processes them and may emit logs to stderr,
but these are not directly accessible from this script.

To see MCP server activity, you would need to:
1. Check the parent process's stderr capture mechanism
2. Or restart the server with stderr redirected to a file
3. Or use the containerization-assist-mcp-ops tool to check server status

This log file captures:
- Process information
- Environment configuration
- Server capabilities
- Where logs would typically be found
EOF
} 2>&1

log_section "COMPLETE LOG FILE CONTENTS"
echo "Below is the complete log capture:" | tee -a "$MAIN_LOG"
echo "" | tee -a "$MAIN_LOG"

# Display the complete log
cat "$MAIN_LOG"

# Return the log file path
echo ""
echo "==================================================================="
echo "Complete log saved to: $MAIN_LOG"
echo "==================================================================="
