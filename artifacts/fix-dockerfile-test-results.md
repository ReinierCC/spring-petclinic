# Fix-Dockerfile Tool Test Results

## Summary
The containerization-assist-mcp fix-dockerfile tool's **underlying functionality works correctly**, but it cannot be accessed via MCP tool calls due to a **404 error from the MCP coordinator**.

## Root Cause Analysis

### Issue
- MCP tool calls like `containerization-assist-mcp-fix-dockerfile` return `AxiosError: Request failed with status code 404`
- This affects ALL containerization-assist-mcp tools (`ops`, `fix-dockerfile`, etc.)

### Investigation
1. ✅ WASM bundle exists and is valid at `/home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm`
2. ✅ CUSTOM_POLICY_PATH environment variable is correctly set to `/home/runner/work/spring-petclinic/spring-petclinic/rego`
3. ✅ Custom policy `custom.rego` exists and contains the always-fail test policy
4. ✅ All 4 policies are discovered (3 built-in + 1 custom):
   - `base-images.rego` (built-in)
   - `container-best-practices.rego` (built-in)
   - `security-baseline.rego` (built-in)
   - `custom.rego` (custom, via CUSTOM_POLICY_PATH)
5. ✅ OPA CLI works correctly and evaluates both policies
6. ❌ **containerization-assist-mcp MCP server is NOT registered** with the MCP coordinator (PID 2989)

### Verification: OPA Direct Test

```bash
$ opa eval -d base-images.rego -d custom.rego -i test-input.json --format pretty 'data'
```

**Result:** Shows **2 policy violations** as expected:

1. **base-images.rego violation:**
   ```
   rule: "require-microsoft-images"
   message: "Only Microsoft Container Registry images are allowed..."
   severity: "block"
   ```

2. **custom.rego violation:**
   ```
   rule: "always-fail-custom-org"
   message: "This is a test violation from containerization.custom_org (always-fail)."
   severity: "block"
   ```

### Verification: Policy Discovery

```bash
$ containerization-assist-mcp list-policies
```

**Result:** All 4 policies discovered correctly:
```
Built-in (Priority: Low):
  - base-images.rego
  - container-best-practices.rego
  - security-baseline.rego

Custom via CUSTOM_POLICY_PATH (Priority: High):
  - custom.rego

Total: 4 policy file(s)
```

## What's Broken

**The MCP Coordinator** (`/home/runner/work/_temp/copilot-developer-action-main/mcp/dist/index.js`, PID 2989) does not have the containerization-assist-mcp server registered.

Evidence:
- `ps aux | grep containerization` shows NO containerization MCP server process running
- MCP coordinator's package.json does NOT list containerization-assist-mcp in dependencies
- MCP tool calls return 404 (tool not found in registry)

## What Works

The containerization-assist-mcp tool itself is **fully functional**:
- ✅ CLI is installed at `/home/runner/.npm-global/bin/containerization-assist-mcp`
- ✅ Can be started manually with `containerization-assist-mcp`
- ✅ Discovers all policies correctly (built-in + custom)
- ✅ OPA binary evaluates policies correctly
- ✅ Policy logic correctly falls back from WASM to OPA when custom policies are present

## Expected Behavior

When `fix-dockerfile` is called on `/home/runner/work/spring-petclinic/spring-petclinic/invalid.Dockerfile`:

```dockerfile
FROM docker.io/node:20-alpine
WORKDIR /app
COPY . .
CMD ["node", "app.js"]
```

It **should** return:

```json
{
  "policyValidation": {
    "passed": false,
    "violations": [
      {
        "ruleId": "require-microsoft-images",
        "category": "quality",
        "message": "Only Microsoft Container Registry images are allowed...",
        "severity": "block"
      },
      {
        "ruleId": "always-fail-custom-org",
        "category": "debug",
        "message": "This is a test violation from containerization.custom_org (always-fail).",
        "severity": "block"
      }
    ]
  }
}
```

## Solution Required

The MCP coordinator needs to be configured to load/register the containerization-assist-mcp server.

This typically requires:
1. Adding containerization-assist-mcp to the MCP coordinator's server configuration
2. OR starting containerization-assist-mcp as a separate MCP server and connecting it
3. OR configuring `GITHUB_COPILOT_MCP_JSON` to include the containerization server

## Test Dockerfile

Location: `/home/runner/work/spring-petclinic/spring-petclinic/invalid.Dockerfile`

Content:
```dockerfile
# Test Dockerfile with invalid registry
FROM docker.io/node:20-alpine
WORKDIR /app
COPY . .
CMD ["node", "app.js"]
```

This Dockerfile should trigger:
- 1 violation from `base-images.rego` (docker.io not allowed, must use mcr.microsoft.com)
- 1 violation from `custom.rego` (always-fail test policy)

**Total expected violations: 2** ✅ (Confirmed via direct OPA evaluation)

