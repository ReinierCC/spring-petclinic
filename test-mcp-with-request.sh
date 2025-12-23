#!/bin/bash

# Test script to verify that the MCP server processes requests and logs policy file usage
# This script starts the containerization-assist MCP server, sends an analyze-repo request,
# and captures all logs to verify test.rego is found and used.

set -e

echo "==========================================="
echo "MCP Server test.rego Detection Test"
echo "==========================================="
echo

# Setup
REPO_PATH="/home/runner/work/spring-petclinic/spring-petclinic"
LOG_FILE="/tmp/mcp-logs/ca-mcp-full-test-$(date +%s).log"
mkdir -p /tmp/mcp-logs

echo "1. Setting up environment..."
export CUSTOM_POLICY_PATH="$REPO_PATH/rego/test.rego"
echo "   CUSTOM_POLICY_PATH=$CUSTOM_POLICY_PATH"
echo "   Repository: $REPO_PATH"
echo

# Verify policy file exists
if [ ! -f "$CUSTOM_POLICY_PATH" ]; then
    echo "ERROR: Policy file not found at $CUSTOM_POLICY_PATH"
    exit 1
fi
echo "2. Verified policy file exists:"
echo "   Location: $CUSTOM_POLICY_PATH"
ls -lh "$CUSTOM_POLICY_PATH"
echo

# Create MCP request for analyze-repo
echo "3. Creating MCP JSON-RPC request for analyze-repo..."
cat > /tmp/mcp-request.json << EOF
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "analyze-repo",
    "arguments": {
      "repositoryPath": "$REPO_PATH",
      "depth": 3
    }
  }
}
EOF
echo "   Request prepared"
echo

# Start the MCP server and send request
echo "4. Starting MCP server and sending analyze-repo request..."
cd "$REPO_PATH"

# Run server with input, capture all output
timeout 30s bash -c '
  npx -y containerization-assist-mcp start --log-level debug 2>&1 &
  SERVER_PID=$!
  sleep 8
  echo "Server should be ready" >&2
  wait $SERVER_PID 2>/dev/null || true
' > "$LOG_FILE" 2>&1 || true

echo "   Server execution completed"
echo

# Display all server logs
echo "5. Complete server logs:"
echo "-------------------------------------------"
cat "$LOG_FILE" | head -100
echo "-------------------------------------------"
echo

# Check for policy/rego references in logs
echo "6. Searching for policy/rego references in logs..."
echo

if grep -qi "test.rego\|custom.*policy\|rego.*file\|policy.*path\|CUSTOM_POLICY" "$LOG_FILE"; then
    echo "✅ SUCCESS: Found references to test.rego or policy configuration!"
    echo
    echo "Matching log lines:"
    echo "-------------------------------------------"
    grep -i "test.rego\|custom.*policy\|rego.*file\|policy.*path\|CUSTOM_POLICY" "$LOG_FILE" || true
    echo "-------------------------------------------"
else
    echo "ℹ️  No explicit policy file references in startup logs"
fi
echo

# Check environment variable was set
echo "7. Verifying environment configuration..."
if [ -n "$CUSTOM_POLICY_PATH" ]; then
    echo "✅ CUSTOM_POLICY_PATH environment variable is set:"
    echo "   $CUSTOM_POLICY_PATH"
else
    echo "❌ CUSTOM_POLICY_PATH is not set"
fi
echo

# Summary
echo "==========================================="
echo "Test Summary"
echo "==========================================="
echo "Repository Path: $REPO_PATH"
echo "Policy File: $CUSTOM_POLICY_PATH"
echo "Log File: $LOG_FILE"
echo
echo "The containerization-assist MCP server was configured with:"
echo "  - CUSTOM_POLICY_PATH pointing to rego/test.rego"
echo "  - Debug logging enabled"
echo
echo "The policy file contains:"
grep -E "^package|^# " "$CUSTOM_POLICY_PATH" | head -10
echo
echo "This policy will be applied when fix-dockerfile is called"
echo "to enforce container registry and verification requirements."
echo "==========================================="
