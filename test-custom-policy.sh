#!/bin/bash
# Test script to verify custom policy evaluation

set -e

echo "====== Custom Policy Evaluation Test ======"
echo ""

# Test 1: Verify OPA is available
echo "Test 1: Check OPA availability"
if command -v opa &> /dev/null; then
    echo "✅ OPA is available: $(opa version | head -1)"
else
    echo "❌ OPA is NOT available"
    exit 1
fi
echo ""

# Test 2: Verify CUSTOM_POLICY_PATH is set
echo "Test 2: Check CUSTOM_POLICY_PATH environment variable"
if [ -n "$CUSTOM_POLICY_PATH" ]; then
    echo "✅ CUSTOM_POLICY_PATH is set: $CUSTOM_POLICY_PATH"
else
    echo "❌ CUSTOM_POLICY_PATH is NOT set"
    exit 1
fi
echo ""

# Test 3: Verify custom policy file exists
echo "Test 3: Check custom policy file"
if [ -f "$CUSTOM_POLICY_PATH/custom.rego" ]; then
    echo "✅ Custom policy file exists: $CUSTOM_POLICY_PATH/custom.rego"
else
    echo "❌ Custom policy file NOT found"
    exit 1
fi
echo ""

# Test 4: Manual OPA evaluation with all policies
echo "Test 4: Manual OPA evaluation with all 4 policies"
BUILTIN_POLICIES="/home/runner/.npm/_npx/1a9240c980b33167/node_modules/containerization-assist-mcp/policies"

cat > /tmp/test-input.json << 'EOF'
{
  "content": "FROM docker.io/node:20-alpine\nWORKDIR /app\nCOPY . .\nCMD [\"node\", \"app.js\"]"
}
EOF

echo "Evaluating with OPA..."
RESULT=$(opa eval \
  -d "$BUILTIN_POLICIES/base-images.rego" \
  -d "$BUILTIN_POLICIES/container-best-practices.rego" \
  -d "$BUILTIN_POLICIES/security-baseline.rego" \
  -d "$CUSTOM_POLICY_PATH/custom.rego" \
  -i /tmp/test-input.json \
  -f json \
  'data.containerization')

# Count violations from each policy
BASE_VIOLATIONS=$(echo "$RESULT" | jq -r '.result[0].expressions[0].value.base_images.result.violations | length')
CUSTOM_VIOLATIONS=$(echo "$RESULT" | jq -r '.result[0].expressions[0].value.custom_org.result.violations | length')

echo "  Base images violations: $BASE_VIOLATIONS"
echo "  Custom policy violations: $CUSTOM_VIOLATIONS"

if [ "$CUSTOM_VIOLATIONS" -gt 0 ]; then
    echo "✅ Custom policy IS being evaluated by OPA"
    echo "  Custom violation: $(echo "$RESULT" | jq -r '.result[0].expressions[0].value.custom_org.result.violations[0].message')"
else
    echo "❌ Custom policy NOT evaluated by OPA"
    exit 1
fi
echo ""

# Test 5: List policies using CLI
echo "Test 5: CLI policy discovery"
POLICY_LIST=$(npx containerization-assist-mcp list-policies 2>&1)

if echo "$POLICY_LIST" | grep -q "custom.rego"; then
    echo "✅ CLI discovers custom policy"
else
    echo "❌ CLI does NOT discover custom policy"
    exit 1
fi
echo ""

echo "====== Summary ======"
echo "✅ All manual tests passed"
echo ""
echo "Custom policy SHOULD be working, but may not be evaluated by MCP server"
echo "This suggests an issue with MCP server initialization or caching"
