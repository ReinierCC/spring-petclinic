# WASM Bundle Status

## Current State
The WASM bundle has been **DISABLED** to force OPA binary usage for policy evaluation.

**File:** `/home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm`
**Status:** Renamed to `policies.wasm.disabled`

## Why This Was Done
The WASM bundle only contains built-in policies and silently skips custom policies. By disabling it, the system is forced to use the OPA binary, which correctly evaluates all policies including custom ones.

## Impact
- ✅ Custom policy violations should now appear in fix-dockerfile output
- ✅ All policy evaluation will use OPA binary (requires OPA to be installed)
- ⚠️  Slightly slower policy evaluation (OPA binary vs WASM)
- ⚠️  Requires OPA to be installed on the system

## To Restore WASM Bundle
If you need to restore the original behavior:
```bash
sudo mv /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm.disabled \
        /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm
```

## Testing
Once MCP server infrastructure is stable:
```bash
# Should now show 2 violations (built-in + custom)
# Use containerization-assist-mcp-fix-dockerfile tool
```

## Date
Applied: 2025-12-18 21:26 UTC
