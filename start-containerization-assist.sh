#!/bin/bash
#
# Containerization Assist MCP Server Wrapper
# This wrapper logs the CUSTOM_POLICY_PATH and other environment variables
# before starting the actual containerization-assist-mcp server
#

echo "========================================" | tee -a /tmp/containerization-assist-startup.log
echo "Containerization Assist MCP Server Starting" | tee -a /tmp/containerization-assist-startup.log
echo "Date: $(date)" | tee -a /tmp/containerization-assist-startup.log
echo "========================================" | tee -a /tmp/containerization-assist-startup.log
echo "" | tee -a /tmp/containerization-assist-startup.log

# Log environment variables
echo "Environment Variables:" | tee -a /tmp/containerization-assist-startup.log
echo "  CUSTOM_POLICY_PATH=${CUSTOM_POLICY_PATH:-<not set>}" | tee -a /tmp/containerization-assist-startup.log
echo "  LOG_LEVEL=${LOG_LEVEL:-<not set>}" | tee -a /tmp/containerization-assist-startup.log
echo "" | tee -a /tmp/containerization-assist-startup.log

# Verify policy path exists if set
if [ -n "$CUSTOM_POLICY_PATH" ]; then
    if [ -d "$CUSTOM_POLICY_PATH" ]; then
        echo "✅ CUSTOM_POLICY_PATH directory found: $CUSTOM_POLICY_PATH" | tee -a /tmp/containerization-assist-startup.log
        echo "Policy files:" | tee -a /tmp/containerization-assist-startup.log
        ls -la "$CUSTOM_POLICY_PATH" | tee -a /tmp/containerization-assist-startup.log
    else
        echo "❌ WARNING: CUSTOM_POLICY_PATH directory not found: $CUSTOM_POLICY_PATH" | tee -a /tmp/containerization-assist-startup.log
    fi
else
    echo "⚠️  CUSTOM_POLICY_PATH not set" | tee -a /tmp/containerization-assist-startup.log
fi

echo "" | tee -a /tmp/containerization-assist-startup.log
echo "Starting containerization-assist-mcp server..." | tee -a /tmp/containerization-assist-startup.log
echo "========================================" | tee -a /tmp/containerization-assist-startup.log
echo "" | tee -a /tmp/containerization-assist-startup.log

# Start the actual server
exec npx -y containerization-assist-mcp start "$@"
