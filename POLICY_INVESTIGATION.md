# Custom Rego Policy Investigation Report

## Problem Statement
Custom rego files in `/rego` are not being respected by the `fix-dockerfile` tool, despite being discovered by `list-policies --show-merged`.

## Investigation Results

### 1. Policy Discovery ✅
**Command:** `npx containerization-assist-mcp list-policies --show-merged`

**Result:** Custom policy IS discovered:
```
Built-in (Priority: Low):
  - base-images.rego
  - container-best-practices.rego
  - security-baseline.rego

Custom via CUSTOM_POLICY_PATH (Priority: High):
  - custom.rego

Total: 4 policy file(s)
```

**Conclusion:** Policy discovery is working correctly.

### 2. Direct OPA Evaluation ✅
**Test:** Running OPA directly with all 4 policies

**Command:**
```bash
opa eval \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/base-images.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/container-best-practices.rego \
  -d /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/security-baseline.rego \
  -d /home/runner/work/spring-petclinic/spring-petclinic/rego/custom.rego \
  -i /tmp/test-input.json \
  -f json \
  'data.containerization'
```

**Result:** All policies evaluated correctly, including custom policy:
```json
{
  "namespace": "custom_org",
  "has_result": true,
  "violations": 1,
  "violation_messages": [
    "This is a test violation from containerization.custom_org (always-fail)."
  ]
}
```

**Conclusion:** Custom policy works correctly when evaluated directly with OPA.

### 3. Tool Evaluation ❌
**Command:** `fix-dockerfile --path invalid.Dockerfile`

**Result:** Only built-in policy violations shown:
```
**Policy Validation:** ❌ FAILED
  Violations: 1
    • Only Microsoft Container Registry images are allowed...
```

**Missing:** Custom policy violation "This is a test violation from containerization.custom_org (always-fail)."

**Conclusion:** Custom policy is NOT being evaluated by the tool.

## Root Cause Analysis

### Code Flow Investigation

1. **Policy Loading** (`policy-rego.js`):
   - Policies are loaded via `loadAndMergeRegoPolicies(policyPaths, logger)`
   - Function checks if all policies are built-in: `allBuiltIn = policyPaths.every(path => fileName in BUILT_IN_POLICY_MODULES)`
   - If `allBuiltIn && wasmPath`: Use pre-compiled WASM bundle
   - Otherwise: Fall back to OPA binary

2. **Built-in Policy Modules** (CRITICAL):
   ```javascript
   const BUILT_IN_POLICY_MODULES = {
       'security-baseline.rego': 'containerization/security/result',
       'base-images.rego': 'containerization/base_images/result',
       'container-best-practices.rego': 'containerization/best_practices/result',
   };
   ```
   
   **Issue:** `custom.rego` is NOT in this mapping!

3. **WASM Evaluation Bug** (`evaluateAllWasmPolicies`):
   ```javascript
   for (const policyPath of policyPaths) {
       const fileName = basename(policyPath);
       const policyModule = BUILT_IN_POLICY_MODULES[fileName];
       if (!policyModule) {
           logger.debug({ fileName }, 'Policy file has no WASM entrypoint mapping, skipping');
           continue;  // ⚠️ SILENTLY SKIPS custom.rego!
       }
       // ... evaluate policy
   }
   ```

### Hypothesis

**Most Likely:** The MCP server has a cached policy evaluator that was created at server startup. The cache determination logic should prevent WASM usage when custom policies are present (`allBuiltIn` should be `false`), but one of the following may be happening:

1. **Stale Cache:** Server was started before `CUSTOM_POLICY_PATH` was set or before `/rego/custom.rego` existed
2. **Policy Loading Bug:** Custom policies not being included in `policyPaths` when passed to `loadAndMergeRegoPolicies`
3. **Conditional Logic Bug:** `allBuiltIn` calculation has a bug or edge case
4. **Evaluation Path Bug:** WASM evaluation is being used when it shouldn't be

### Supporting Evidence

**Orchestrator Caching** (`orchestrator.js`):
```javascript
let policyCache;
let policyLoadPromise;

async function execute(request) {
    // Load policies once (with Promise-based guard to prevent race conditions)
    if (!policyLoadPromise) {
        policyLoadPromise = (async () => {
            const policyPaths = discoverPolicies(logger);
            // ... load and cache policies
            policyCache = policyResult.value;
        })();
    }
    // ... use policyCache for all subsequent tool executions
}
```

Once policies are loaded and cached, they are reused for ALL subsequent tool executions until the server restarts.

## Recommended Solutions

### Solution 1: Clear Policy Cache (Immediate)
**Action:** Restart the MCP server to force policy cache reload

**Steps:**
1. Stop all running MCP server instances
2. Ensure `CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego` is set
3. Start fresh MCP server instance
4. Run `fix-dockerfile` again

### Solution 2: Add Custom Policy to WASM Bundle (Long-term)
**Action:** Include custom policies in the WASM bundle entrypoint mapping or create a dynamic mapping mechanism

**Code Change in `policy-rego.js`:**
```javascript
// Instead of hard-coded mapping, dynamically generate entrypoints
const policyModule = BUILT_IN_POLICY_MODULES[fileName] || 
                     `${POLICY_NAMESPACE}/${basename(fileName, '.rego').replace(/-/g, '_')}/result`;
```

### Solution 3: Add Cache Invalidation (Best Practice)
**Action:** Add mechanism to invalidate policy cache when `CUSTOM_POLICY_PATH` changes or when policies are modified

### Solution 4: Improve Error Reporting
**Action:** Add warning/error when policies are skipped due to missing WASM mapping

**Code Change in `evaluateAllWasmPolicies`:**
```javascript
if (!policyModule) {
    logger.warn({ fileName }, 'Policy file has no WASM entrypoint mapping, will be skipped in WASM mode');
    continue;
}
```

## Test Plan to Verify Fix

1. Ensure clean state (no running MCP servers)
2. Set `CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego`
3. Run `list-policies --show-merged` → Should show custom.rego
4. Run `fix-dockerfile --path invalid.Dockerfile` → Should show BOTH violations:
   - Microsoft Container Registry violation (from base-images.rego)
   - Always-fail violation (from custom.rego)
5. Verify logs show OPA binary being used (not WASM)

## Conclusion

The custom rego policy IS being discovered and CAN be evaluated (proven by direct OPA testing). The issue is in how the MCP server evaluates policies at runtime, likely due to:

1. **Policy cache** created before custom policies were available
2. **WASM evaluation** being used when OPA binary should be used
3. **Silent skipping** of policies without WASM entrypoint mappings

**Recommended immediate action:** Restart MCP server with correct `CUSTOM_POLICY_PATH` set.

**Recommended code fix:** Ensure OPA binary is used (not WASM) when custom policies are present, OR add custom policies to WASM bundle with dynamic entrypoint mapping.
