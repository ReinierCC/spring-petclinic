# Custom Rego Policy Investigation - README

This investigation examined why custom rego policy files in `/rego` directory are not being respected by the `containerization-assist-mcp` fix-dockerfile tool.

## Quick Start

### Run the Investigation Tests

```bash
# 1. Verify environment setup
echo $CUSTOM_POLICY_PATH
# Should output: /home/runner/work/spring-petclinic/spring-petclinic/rego

# 2. Run the test script
./test-custom-policy.sh

# 3. Try the fix-dockerfile tool
npx containerization-assist-mcp
# Then in MCP interface:
fix-dockerfile invalid.Dockerfile
```

## Files in This Investigation

| File | Purpose |
|------|---------|
| `INVESTIGATION_FINDINGS.md` | Detailed evidence and analysis |
| `SOLUTION.md` | Proposed fixes and workarounds |
| `FINAL_SUMMARY.md` | Comprehensive summary and recommendations |
| `test-custom-policy.sh` | Automated test script |
| `README_INVESTIGATION.md` | This file |

## Key Findings

### ✅ What Works
- Custom policy discovery via `list-policies` command
- Manual OPA evaluation with all 4 policies (3 built-in + 1 custom)
- Policy syntax and logic are correct
- CUSTOM_POLICY_PATH environment variable is set correctly

### ❌ What Doesn't Work
- Custom policy evaluation in `fix-dockerfile` MCP tool
- Only shows 1 violation (from built-in policy)
- Missing the custom policy violation

### 🔍 Root Cause
**MCP server policy caching** - Policies are loaded once on first tool execution and never reloaded.

If custom policies are added after the MCP server starts, they won't be evaluated.

## Verification Commands

```bash
# 1. List policies (should show custom.rego)
npx containerization-assist-mcp list-policies --show-merged

# 2. Manual OPA test (should show 2 violations)
cat > /tmp/test-input.json << 'EOF'
{"content": "FROM docker.io/node:20-alpine\nWORKDIR /app\nCOPY . .\nCMD [\"node\", \"app.js\"]"}
EOF

opa eval \
  -d /home/runner/.npm/_npx/.../policies/base-images.rego \
  -d /home/runner/.npm/_npx/.../policies/container-best-practices.rego \
  -d /home/runner/.npm/_npx/.../policies/security-baseline.rego \
  -d rego/custom.rego \
  -i /tmp/test-input.json \
  -f json \
  'data.containerization' | jq '.result[0].expressions[0].value | to_entries | map({key: .key, violations: .value.result.violations | length})'

# Should show:
# [
#   {"key": "base_images", "violations": 1},
#   {"key": "best_practices", "violations": 0},
#   {"key": "custom_org", "violations": 1},  ← This one is missing from MCP tool!
#   {"key": "security", "violations": 0}
# ]
```

## Recommendations

### For This Repository
1. Document the limitation in project README
2. Ensure CUSTOM_POLICY_PATH is set before MCP server starts
3. Restart MCP server when policies change

### For Upstream (Azure/containerization-assist)
1. Add file system watching to invalidate cache on policy changes
2. Add environment variable to disable policy caching for development
3. Add TTL-based cache expiration
4. Add manual cache invalidation tool

See `SOLUTION.md` for detailed implementation proposals.

## Upstream Status

Checked `Azure/containerization-assist` repository:

- **Version Used:** 1.0.2 (published)
- **Latest Dev:** 1.1.0-dev.1 (in development)
- **Active Branches:** 
  - `thgamble/policytest` - Policy loading investigation
  - `thgamble/loading` - Loader refactoring
- **Status:** Team is actively working on policy loading improvements
- **Fixes:** Path resolution bugs fixed in feature branches (not yet released)

## Conclusion

The containerization-assist source code is **functionally correct** for custom policy evaluation. The issue is a **design limitation** where policies are cached and never reloaded during MCP server lifetime.

**Workaround:** Ensure custom policies exist and CUSTOM_POLICY_PATH is set BEFORE starting the MCP server.

**Long-term fix:** Contribute upstream PR to add cache invalidation mechanism.

---

**Investigation Date:** 2025-12-18  
**Investigated By:** GitHub Copilot  
**Repository:** ReinierCC/spring-petclinic  
**Upstream:** Azure/containerization-assist
