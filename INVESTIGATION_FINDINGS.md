# Investigation Findings: Custom Rego Policy Not Respected

## Summary

Custom rego policies in `/rego` directory are discovered but not evaluated when calling `fix-dockerfile` tool through the MCP interface.

## Evidence

### 1. Custom Policy Discovery ✅ WORKS
Running `npx containerization-assist-mcp list-policies --show-merged` successfully discovers the custom policy:
```
Custom via CUSTOM_POLICY_PATH (Priority: High):
  - custom.rego
```

### 2. Manual OPA Evaluation ✅ WORKS
Direct OPA evaluation with all 4 policies (3 built-in + 1 custom) produces expected violations:
```bash
opa eval -d .../base-images.rego -d .../container-best-practices.rego \
  -d .../security-baseline.rego -d rego/custom.rego \
  -i /tmp/test-input.json -f json 'data.containerization'
```

Result: 2 violations (1 from base_images, 1 from custom_org)

### 3. MCP Tool Evaluation ❌ FAILS
Calling `fix-dockerfile` through MCP returns only 1 violation (from base_images.rego):
```
Policy Validation: ❌ FAILED
  Violations: 1
    • Only Microsoft Container Registry images are allowed...
```

**Missing:** The custom policy violation: "This is a test violation from containerization.custom_org (always-fail)."

## Analysis

### Environment Setup
- `CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego` ✅ Set correctly
- Custom policy file exists at expected location ✅ 
- Custom policy syntax is valid (tested with OPA) ✅
- Package version: 1.0.2 (includes custom policy support) ✅

### Code Review (Azure/containerization-assist v1.1.0-dev.1)

**Policy Discovery (`src/app/orchestrator.ts:155-180`):**
- Correctly discovers built-in policies
- Correctly discovers custom policies from CUSTOM_POLICY_PATH
- Priority ordering: built-in < user < custom ✅

**Policy Loading (`src/config/policy-rego.ts:897-1036`):**
- Logic for WASM vs OPA selection appears correct:
  ```typescript
  const allBuiltIn = policyPaths.every(path => {
    const fileName = basename(path);
    return fileName in BUILT_IN_POLICY_MODULES;
  });
  
  if (allBuiltIn && wasmPath) {
    // Use WASM (fast, no OPA needed)
  } else {
    // Use OPA binary for custom policies
  }
  ```
- When custom.rego is present, `allBuiltIn` = false ✅
- Falls through to OPA binary path ✅

**Policy Evaluation (`src/config/policy-rego.ts:716-885`):**
- Passes all policy paths to OPA with multiple `-d` flags ✅
- Queries `data.containerization` namespace ✅
- Merges results from all namespaces dynamically ✅

**Violation Merging (`src/config/policy-rego.ts:782-823`):**
```typescript
for (const [, nsObj] of Object.entries(containerization)) {
  if (nsObj && typeof nsObj === 'object' && 'result' in nsObj) {
    const nsResult = nsObj.result;
    if (nsResult.violations) {
      combinedResult.violations.push(...nsResult.violations);
    }
  }
}
```
This should correctly merge violations from both `base_images.result` and `custom_org.result` ✅

## Hypothesis

The code logic appears correct. The issue is likely one of:

1. **MCP Server Caching**: The MCP server may have cached policies before CUSTOM_POLICY_PATH was set or before custom.rego existed

2. **Process Isolation**: The MCP server process may not have inherited the CUSTOM_POLICY_PATH environment variable

3. **Version Mismatch**: The MCP server may be running an older version (< 1.0.2) without custom policy support

4. **OPA Binary Unavailable**: If OPA binary is not available to the MCP server process, it might silently fall back to WASM-only mode, skipping custom policies

## Recommended Fix

To definitively identify the issue, we need to:

1. Add detailed logging to show which policies are being loaded and evaluated
2. Ensure CUSTOM_POLICY_PATH is set before MCP server starts
3. Clear any policy cache when CUSTOM_POLICY_PATH changes
4. Add fallback error message when OPA binary is required but not available

## Next Steps

1. Verify OPA binary is available in MCP server process
2. Add logging/debugging to policy-rego.ts to show policy evaluation flow
3. Test with MCP server restart after setting CUSTOM_POLICY_PATH
4. Consider adding policy cache invalidation mechanism
