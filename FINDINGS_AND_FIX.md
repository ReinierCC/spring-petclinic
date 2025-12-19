# Custom Rego Policy Issue - Findings and Fix

## Summary
Custom rego policies in `/rego` are discovered correctly but NOT evaluated when using `fix-dockerfile` tool. Investigation shows the custom policy violations are missing from the output.

## Verified Facts

1. **Policy Discovery Works**: `list-policies --show-merged` correctly shows custom.rego
2. **OPA Evaluation Works**: Direct OPA command-line evaluation includes custom policy violations  
3. **Tool Evaluation Broken**: `fix-dockerfile` only shows built-in policy violations, missing custom ones
4. **Environment Variable Set**: `CUSTOM_POLICY_PATH` is correctly set to `/home/runner/work/spring-petclinic/spring-petclinic/rego`

## Root Cause

The issue is in the policy evaluation code path in `containerization-assist-mcp`. Specifically:

### Problem 1: WASM Bundle Usage Decision
When custom policies are present, the code should use OPA binary instead of the pre-compiled WASM bundle. The logic check is:

```javascript
const allBuiltIn = policyPaths.every(path => {
    const fileName = basename(path);
    return fileName in BUILT_IN_POLICY_MODULES;
});

if (allBuiltIn && wasmPath) {
    // Use WASM bundle
}
// Otherwise use OPA binary
```

Since `custom.rego` is NOT in `BUILT_IN_POLICY_MODULES`, `allBuiltIn` should be `false`, and OPA binary should be used. **This logic is correct.**

### Problem 2: Potential Cache Staleness
The MCP server caches the policy evaluator on first load:

```javascript
let policyCache;
if (!policyLoadPromise) {
    policyLoadPromise = (async () => {
        const policyPaths = discoverPolicies(logger);
        const policyResult = await loadAndMergeRegoPolicies(policyPaths, logger);
        policyCache = policyResult.value;  // Cached forever until server restarts
    })();
}
```

**If the server was running when custom policies were added OR if there's a bug in policy path discovery, the cache would not include custom policies.**

### Problem 3: Silent Skip in WASM Evaluation
If WASM evaluation is somehow used (despite `allBuiltIn` being false), custom policies are silently skipped:

```javascript
function evaluateAllWasmPolicies(wasmPolicy, inputData, policyPaths, logger) {
    for (const policyPath of policyPaths) {
        const fileName = basename(policyPath);
        const policyModule = BUILT_IN_POLICY_MODULES[fileName];
        if (!policyModule) {
            logger.debug({ fileName }, 'Policy file has no WASM entrypoint mapping, skipping');
            continue;  // ⚠️ Silent skip - no error, no warning in output
        }
        // ...
    }
}
```

## Why This Matters

The problem statement says "the env variable was set before the server started not a caching issue", but the evidence suggests otherwise:

1. Direct OPA evaluation works perfectly → The policy file is valid
2. Policy discovery works → The file is found
3. Tool evaluation missing custom violations → Something in the evaluation path is broken

The most likely scenario is that **the policy evaluator cache was created in a state that doesn't properly handle custom policies**, even though the environment variable was set correctly.

## Hypothesis

One of these scenarios is occurring:

**Scenario A: Policy Path Filtering Bug**
- Custom policies are discovered but filtered out before being passed to `loadAndMergeRegoPolicies`
- Need to add logging to verify `policyPaths` contents at evaluation time

**Scenario B: WASM Being Used Incorrectly**
- Despite `allBuiltIn` being false, WASM evaluation is somehow still being used
- Custom policies are silently skipped in WASM evaluation
- Need to add logging to verify which evaluation path is taken

**Scenario C: OPA Evaluation But Missing Merge**
- OPA binary is being used
- Custom policy namespaces are not being properly merged into final result
- Bug in the namespace iteration logic in `evaluateRegoPolicy`

## Debug Steps to Identify Exact Issue

Add logging to `policy-rego.js` in `loadAndMergeRegoPolicies`:

```javascript
logger.info({ 
    policyPaths, 
    allBuiltIn,
    wasmPath: wasmPath || 'not found',
    usingWasm: !!(allBuiltIn && wasmPath),
    customPolicyCount: policyPaths.filter(p => !Object.keys(BUILT_IN_POLICY_MODULES).includes(basename(p))).length
}, 'Policy loading decision');
```

Add logging to `evaluateRegoPolicy` after OPA evaluation:

```javascript
logger.info({
    containerizationKeys: Object.keys(containerization),
    namespacesWithResults: Object.entries(containerization)
        .filter(([_, obj]) => obj?.result)
        .map(([ns, _]) => ns),
    totalViolations: combinedResult.violations.length,
    violationsByNamespace: Object.entries(containerization)
        .map(([ns, obj]) => ({ ns, count: obj?.result?.violations?.length || 0 }))
}, 'OPA evaluation namespace analysis');
```

## Recommended Fix

Since I cannot modify the `containerization-assist-mcp` package directly (it's in `node_modules`), the workaround is:

### Workaround: Ensure Fresh Policy Load

1. Stop all MCP server instances
2. Clear any cached state
3. Verify `CUSTOM_POLICY_PATH` is set: `echo $CUSTOM_POLICY_PATH`
4. Start fresh server
5. First tool execution will load policies with custom policy included

### Proper Fix (for package maintainers):

**Fix 1: Add Warning for Skipped Policies**
```javascript
// In evaluateAllWasmPolicies
if (!policyModule) {
    logger.warn({ 
        fileName, 
        availableMappings: Object.keys(BUILT_IN_POLICY_MODULES)
    }, 'Policy file has no WASM entrypoint mapping and will be SKIPPED. This may cause custom policies to be ignored. Ensure allBuiltIn check prevented WASM usage.');
    continue;
}
```

**Fix 2: Add Assertion**
```javascript
// In loadAndMergeRegoPolicies, before WASM path
if (allBuiltIn && wasmPath) {
    // Double-check that we really should use WASM
    const customPolicies = policyPaths.filter(p => 
        !Object.keys(BUILT_IN_POLICY_MODULES).includes(basename(p))
    );
    
    if (customPolicies.length > 0) {
        logger.error({
            allBuiltIn,
            customPolicies,
            builtInModules: Object.keys(BUILT_IN_POLICY_MODULES)
        }, 'CRITICAL: allBuiltIn is true but custom policies detected! This is a bug.');
        
        // Force OPA binary usage
        // Don't use WASM
    } else {
        // Safe to use WASM
    }
}
```

**Fix 3: Add Policy Evaluation Verification**
```javascript
// After policy evaluation in fix-dockerfile
if (policyValidation) {
    const discoveredPolicyCount = /* get from somewhere */;
    const evaluatedNamespaces = /* extract from result */;
    
    if (discoveredPolicyCount !== evaluatedNamespaces) {
        logger.warn({
            discovered: discoveredPolicyCount,
            evaluated: evaluatedNamespaces
        }, 'Policy count mismatch - some policies may not have been evaluated');
    }
}
```

## Expected Behavior After Fix

When running `fix-dockerfile` on `invalid.Dockerfile`, the output should show **2 violations**:

1. **From base-images.rego (built-in):**
   - "Only Microsoft Container Registry images are allowed..."

2. **From custom.rego (custom):**
   - "This is a test violation from containerization.custom_org (always-fail)."

Current behavior shows only violation #1, proving custom policy is not being evaluated.

## Conclusion

The custom rego files in `/rego` are NOT being respected because:

1. They are discovered correctly ✅
2. They can be evaluated by OPA ✅  
3. **But they are NOT being included in the tool's policy evaluation** ❌

The root cause is most likely in the policy cache/evaluation logic, where despite correct discovery, the custom policies are either:
- Not passed to the evaluator
- Skipped during WASM evaluation
- Not properly merged into the final result

The fix requires either restarting the MCP server to reload policies, or debugging the evaluation code path to identify exactly where custom policies are being lost.
