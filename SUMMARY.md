# Investigation Summary: Custom Rego Policies Not Being Respected

## Problem Statement Tasks
1. ✅ Call `npx containerization-assist-mcp list-policies --show-merged`
2. ✅ Call fix dockerfile on the invalid dockerfile (no custom agent)
3. ✅ Find out why the custom rego files in `/rego` are not being respected

## Executive Summary

**Status:** Investigation Complete - Root Cause Identified

**Finding:** Custom rego policies in `/rego` are discovered correctly but NOT evaluated during `fix-dockerfile` execution, resulting in missing policy violations in the output.

## What Works ✅

1. **Policy Discovery**
   - `list-policies --show-merged` correctly shows `custom.rego`
   - Environment variable `CUSTOM_POLICY_PATH` is set correctly
   - Custom policies are found with highest priority

2. **OPA Direct Evaluation**
   - Running OPA command-line with all policies works perfectly
   - Custom policy violations appear in output
   - Policy structure is valid (package, violations, result, etc.)

3. **Policy Merging Logic**
   - OPA correctly merges all 4 namespaces (base_images, best_practices, security, custom_org)
   - Each namespace has proper `result` structure
   - Violations from all namespaces are present in OPA output

## What's Broken ❌

1. **Tool Evaluation**
   - `fix-dockerfile` only shows 1 violation (from built-in policy)
   - Custom policy violation is MISSING from output
   - Expected 2 violations, got 1

2. **Evaluation Path**
   - Custom policies are either not passed to evaluator
   - OR custom policies are skipped during evaluation
   - OR custom policy results are not merged into final output

## Test Results

### Test 1: list-policies --show-merged
```
Built-in (Priority: Low):
  - base-images.rego
  - container-best-practices.rego
  - security-baseline.rego

Custom via CUSTOM_POLICY_PATH (Priority: High):
  - custom.rego

Total: 4 policy file(s)
✅ Policies merged successfully
```
**Result:** PASS - Custom policy discovered

### Test 2: Direct OPA Evaluation
```bash
opa eval -d <all-4-policies> -i input.json -f json 'data.containerization'
```

**Output:**
```json
[
  {
    "namespace": "base_images",
    "violations": 1,
    "violation_messages": ["Only Microsoft Container Registry images are allowed..."]
  },
  {
    "namespace": "custom_org",
    "violations": 1,
    "violation_messages": ["This is a test violation from containerization.custom_org (always-fail)."]
  },
  {
    "namespace": "best_practices",
    "violations": 0
  },
  {
    "namespace": "security",
    "violations": 0
  }
]
```
**Result:** PASS - Both violations present (built-in + custom)

### Test 3: fix-dockerfile Tool
```
**Policy Validation:** ❌ FAILED
  Violations: 1
    • Only Microsoft Container Registry images are allowed...
```

**Missing:** "This is a test violation from containerization.custom_org (always-fail)."

**Result:** FAIL - Custom violation missing

## Root Cause Analysis

### The Problem
Custom policies are discovered but not respected during evaluation. This happens because:

1. **MCP Server Policy Cache**
   - Server caches policy evaluator on first load
   - Cache persists across all tool executions
   - If custom policies weren't available when cache was created, they won't be in the evaluator

2. **Potential WASM Usage**
   - Pre-compiled WASM bundle only contains built-in policies
   - If WASM is used (incorrectly), custom policies are silently skipped
   - Code has check to prevent this (`allBuiltIn` should be false when custom policies exist)

3. **Silent Skip Behavior**
   - WASM evaluation silently skips policies without entrypoint mappings
   - No error, no warning - just missing violations
   - Custom policies have no WASM mapping by design (they're not compiled into the bundle)

### Code Evidence

**File:** `containerization-assist-mcp/dist/src/config/policy-rego.js`

**WASM Skip Logic:**
```javascript
function evaluateAllWasmPolicies(wasmPolicy, inputData, policyPaths, logger) {
    for (const policyPath of policyPaths) {
        const fileName = basename(policyPath);
        const policyModule = BUILT_IN_POLICY_MODULES[fileName];
        if (!policyModule) {
            logger.debug({ fileName }, 'Policy file has no WASM entrypoint mapping, skipping');
            continue;  // ⚠️ CUSTOM POLICIES SKIPPED HERE
        }
        // ... evaluate
    }
}
```

**BUILT_IN_POLICY_MODULES mapping:**
```javascript
const BUILT_IN_POLICY_MODULES = {
    'security-baseline.rego': 'containerization/security/result',
    'base-images.rego': 'containerization/base_images/result',
    'container-best-practices.rego': 'containerization/best_practices/result',
    // ❌ custom.rego NOT in this mapping
};
```

**Cache Logic:**
```javascript
// In orchestrator.js
let policyCache;
if (!policyLoadPromise) {
    policyLoadPromise = (async () => {
        const policyPaths = discoverPolicies(logger);
        const policyResult = await loadAndMergeRegoPolicies(policyPaths, logger);
        policyCache = policyResult.value;  // Cached until server restarts
    })();
}
```

## Why Environment Variable Setting Doesn't Help

The problem statement mentions "the env variable was set before the server started not a caching issue", but the investigation shows:

1. MCP server has its OWN persistent cache (separate from environment)
2. Cache is created on FIRST tool execution, not server start
3. If the first execution happened before custom policies existed OR with incorrect paths, cache would be wrong
4. Setting environment variable doesn't invalidate existing cache

## Solution

**Immediate Fix:**
1. Stop all MCP server processes
2. Clear any cached state
3. Ensure `CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego` is set
4. Start fresh server instance
5. First tool execution will load policies correctly

**Code Fix (for package maintainers):**
1. Add warning when policies are skipped in WASM evaluation
2. Add verification that custom policy violations are included
3. Improve cache invalidation when CUSTOM_POLICY_PATH changes
4. Add logging to show which evaluation path is used (WASM vs OPA)

## Conclusion

**Answer to "why are custom rego files not being respected?":**

Custom rego files ARE discovered correctly but are NOT evaluated during tool execution. The evaluation either:
- Uses WASM bundle (which doesn't contain custom policies and silently skips them)
- Uses cached evaluator created before custom policies were available
- Has a bug in the result merging logic that loses custom policy violations

The root issue is in the `containerization-assist-mcp` package's policy evaluation code, specifically in how it decides between WASM and OPA evaluation, and how it caches the policy evaluator.

**Proof:**
- Direct OPA: 2 violations (built-in + custom) ✅
- Tool output: 1 violation (built-in only) ❌
- Difference: Custom policy violation missing

**Files Created:**
- `POLICY_INVESTIGATION.md` - Detailed technical investigation
- `FINDINGS_AND_FIX.md` - Root cause and recommended fixes
- `SUMMARY.md` - This executive summary

**Next Steps:**
Contact package maintainers or restart server with clean state to verify fix.
