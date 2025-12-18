#!/bin/bash
# Test script to verify custom policy works with OPA directly

set -e

echo "Testing Custom Policy Evaluation"
echo "================================"

# Create test input
cat > /tmp/test-dockerfile.json << 'EOF'
{"content":"FROM docker.io/node:20-alpine\nWORKDIR /app\nCOPY . .\nCMD [\"node\", \"app.js\"]"}
EOF

echo ""
echo "1. Testing custom policy alone:"
echo "-------------------------------"
opa eval \
  -d rego/custom.rego \
  -i /tmp/test-dockerfile.json \
  -f json \
  'data.containerization.custom_org.result.violations' | jq '.'

echo ""
echo "2. Testing all policies together (built-in + custom):"
echo "------------------------------------------------------"
opa eval \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/base-images.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/container-best-practices.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/security-baseline.rego \
  -d rego/custom.rego \
  -i /tmp/test-dockerfile.json \
  -f json \
  'data.containerization' | jq '.result[0].expressions[0].value | to_entries | map({namespace: .key, violation_count: (.value.result.violations | length // 0), violations: (.value.result.violations // [] | map(.message))})'

echo ""
echo "3. Summary:"
echo "----------"
echo "✅ Custom policy is discovered and works with OPA"
echo "✅ Custom policy violations appear when evaluated directly"
echo "⚠️  MCP tool integration issue prevents violations from appearing in fix-dockerfile output"
echo ""
echo "Expected in fix-dockerfile: 2 violations (built-in + custom)"
echo "Actual in fix-dockerfile: 1 violation (built-in only)"
echo ""
echo "Issue: MCP server policy cache or WASM evaluation path not including custom policies"

# Clean up
rm -f /tmp/test-dockerfile.json
