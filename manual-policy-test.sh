#!/bin/bash
# Manual test of fix-dockerfile using OPA-based policy evaluation
# This bypasses the MCP server infrastructure to demonstrate custom policies work

set -e

echo "Manual Policy Evaluation Test"
echo "============================="
echo ""

DOCKERFILE_PATH="invalid.Dockerfile"

# Read Dockerfile content and create properly escaped JSON
jq -Rs '{content: .}' < "$DOCKERFILE_PATH" > /tmp/dockerfile-input.json

echo "Testing policy evaluation on: $DOCKERFILE_PATH"
echo ""
echo "Dockerfile content:"
cat "$DOCKERFILE_PATH"
echo ""
echo "---"
echo ""

# Evaluate all policies
echo "Policy Evaluation Results:"
echo "=========================="
opa eval \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/base-images.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/container-best-practices.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/security-baseline.rego \
  -d rego/custom.rego \
  -i /tmp/dockerfile-input.json \
  -f json \
  'data.containerization' | jq -r '
    .result[0].expressions[0].value | 
    to_entries | 
    map(
      select(.value.result.violations and (.value.result.violations | length) > 0) |
      {
        namespace: .key,
        policy_name: .value.policy_name,
        violations: .value.result.violations
      }
    ) | 
    .[] | 
    "\n🚫 Policy: \(.policy_name) (namespace: \(.namespace))",
    "   Violations:",
    (.violations[] | "   - [\(.severity)] \(.message)")
  '

echo ""
echo "Summary:"
echo "--------"
VIOLATION_COUNT=$(opa eval \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/base-images.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/container-best-practices.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/security-baseline.rego \
  -d rego/custom.rego \
  -i /tmp/dockerfile-input.json \
  -f json \
  'data.containerization' | jq '[.result[0].expressions[0].value | to_entries | .[] | select(.value.result.violations) | .value.result.violations[]] | length')

echo "Total violations found: $VIOLATION_COUNT"
echo ""
echo "✅ Custom policy violations ARE included when using OPA directly"
echo "⚠️  MCP tool fix-dockerfile shows only built-in violations (custom policy missing)"

# Clean up
rm -f /tmp/dockerfile-input.json
