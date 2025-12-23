#!/bin/bash

# Script to verify containerization-assist server logs show CUSTOM_POLICY_PATH
# This demonstrates the policy path configuration and server startup logs

echo "=================================="
echo "Containerization Assist Server Log Verification"
echo "=================================="
echo ""

# Define the custom policy path
POLICY_PATH="/home/runner/work/spring-petclinic/spring-petclinic/rego"
export CONTAINERIZATION_ASSIST_POLICY_PATH="$POLICY_PATH"

echo "📋 Configuration:"
echo "  CONTAINERIZATION_ASSIST_POLICY_PATH=${CONTAINERIZATION_ASSIST_POLICY_PATH}"
echo ""

# List rego files in the policy path
echo "📄 Rego policy files found in ${POLICY_PATH}:"
find "$POLICY_PATH" -name "*.rego" -type f 2>/dev/null | while read -r file; do
    echo "  - $(basename "$file")"
done
echo ""

echo "=================================="
echo "Starting Containerization Assist Server..."
echo "=================================="
echo ""

# Start the server with debug logging to capture policy loading messages
# Using a timeout to capture startup logs then exit
timeout 5s npm exec containerization-assist-mcp -- start --log-level debug 2>&1 | tee /tmp/containerization-assist-startup.log || true

echo ""
echo "=================================="
echo "Server Startup Log Analysis"
echo "=================================="
echo ""

# Extract and display policy-related log messages
echo "🔍 Policy Loading Messages:"
grep -E "policy|Policy|POLICY|rego|Rego" /tmp/containerization-assist-startup.log 2>/dev/null || echo "  No policy messages found"
echo ""

echo "🔍 Policies Loaded Summary:"
grep "policiesLoaded" /tmp/containerization-assist-startup.log 2>/dev/null | tail -1 || echo "  No summary found"
echo ""

echo "🔍 Configuration Log:"
grep "workspace" /tmp/containerization-assist-startup.log 2>/dev/null | head -1 || echo "  No workspace config found"
echo ""

echo "=================================="
echo "Verification Summary"
echo "=================================="
echo ""

# Check if policies were loaded
if grep -q "policiesLoaded" /tmp/containerization-assist-startup.log 2>/dev/null; then
    POLICIES_COUNT=$(grep "policiesLoaded" /tmp/containerization-assist-startup.log | grep -o '"policiesLoaded":[0-9]*' | grep -o '[0-9]*' | tail -1)
    RULES_COUNT=$(grep "totalRules" /tmp/containerization-assist-startup.log | grep -o '"totalRules":[0-9]*' | grep -o '[0-9]*' | tail -1)
    
    echo "✅ Policy loading verified!"
    echo "   - Policies loaded: $POLICIES_COUNT"
    echo "   - Total rules: $RULES_COUNT"
    echo "   - Policy path: $CONTAINERIZATION_ASSIST_POLICY_PATH"
else
    echo "❌ Policy loading could not be verified from logs"
fi
echo ""

echo "📊 Full startup log saved to: /tmp/containerization-assist-startup.log"
echo ""
echo "✅ Verification complete!"
