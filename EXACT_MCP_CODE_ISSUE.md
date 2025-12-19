# Exact MCP Code Issue and Fix

## Location of the Bug
File: `/home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/dist/src/config/policy-rego.js`

## The Bug: Silent Skip of Custom Policies

### Function: `evaluateAllWasmPolicies` (Line ~150)

**Current Code (BUGGY):**
```javascript
function evaluateAllWasmPolicies(wasmPolicy, inputData, policyPaths, logger) {
    const allViolations = [];
    const allWarnings = [];
    const allSuggestions = [];
    let overallAllow = true;
    
    logger.debug({ policyCount: policyPaths.length }, 'Evaluating all WASM policy modules');
    
    for (const policyPath of policyPaths) {
        const fileName = basename(policyPath);
        const policyModule = BUILT_IN_POLICY_MODULES[fileName];
        
        if (!policyModule) {
            logger.debug({ fileName }, 'Policy file has no WASM entrypoint mapping, skipping');
            continue;  // ⚠️ BUG: Custom policies are silently skipped here!
        }
        
        // ... rest of evaluation
    }
    
    return {
        allow: overallAllow,
        violations: allViolations,
        warnings: allWarnings,
        suggestions: allSuggestions,
        summary: {
            total_violations: allViolations.length,
            total_warnings: allWarnings.length,
            total_suggestions: allSuggestions.length,
        },
    };
}
```

**The Problem:**
- `BUILT_IN_POLICY_MODULES` only contains: `security-baseline.rego`, `base-images.rego`, `container-best-practices.rego`
- `custom.rego` is NOT in this mapping
- When `policyModule` is undefined, the function **silently skips** the policy with only a debug log
- No error, no warning, no fallback - custom policy is just ignored

## The Root Cause Decision Point

### Function: `loadAndMergeRegoPolicies` (Line ~280)

**Current Code:**
```javascript
export async function loadAndMergeRegoPolicies(policyPaths, logger) {
    // ... validation ...
    
    // Check if all policies are built-in (can use WASM bundle)
    const allBuiltIn = policyPaths.every(path => {
        const fileName = basename(path);
        return fileName in BUILT_IN_POLICY_MODULES;
    });
    
    // Fast path: Use pre-compiled WASM bundle for built-in policies (no OPA needed)
    if (allBuiltIn && wasmPath) {
        try {
            logger.info({ wasmPath, policyCount: policyPaths.length }, 
                'Loading pre-compiled WASM bundle for built-in policies');
            
            const wasmBytes = await readFile(wasmPath);
            const wasmPolicy = await loadWasmPolicy(wasmBytes);
            
            // Create evaluator that queries all requested policy modules
            const evaluator = {
                policyPaths,
                evaluate: async (input) => {
                    const inputData = typeof input === 'string' ? { content: input } : input;
                    return evaluateAllWasmPolicies(wasmPolicy, inputData, policyPaths, logger);
                    // ⚠️ This calls the buggy function that skips custom policies
                },
                // ...
            };
            
            logger.info({ policyPaths }, 'Built-in policies loaded via WASM bundle (zero-dependency mode)');
            return Success(evaluator);
        }
        catch (wasmError) {
            logger.warn({ error: wasmError }, 'Failed to load WASM bundle, falling back to OPA binary');
            // Continue to OPA binary fallback
        }
    }
    
    // Fallback path: Use OPA binary for custom policies or if WASM failed
    const opaBinary = getOpaBinaryPath();
    // ... OPA binary evaluation (this WORKS with custom policies) ...
}
```

**The Logic:**
1. If ALL policies are built-in (`allBuiltIn = true`) AND WASM bundle exists → Use WASM
2. Otherwise → Use OPA binary

**When Custom Policy is Present:**
- `custom.rego` is NOT in `BUILT_IN_POLICY_MODULES`
- So `allBuiltIn = false`
- Should use OPA binary (which works correctly)

**Why It Still Fails:**
Even though the code SHOULD use OPA binary when custom policies are present, the issue persists. This suggests one of:
1. The policy cache was created when `allBuiltIn` was incorrectly `true`
2. There's a race condition or timing issue
3. The WASM path is being used despite `allBuiltIn` being `false`

## Exact Fix Options

### Option 1: Force OPA Binary Usage (Temporary Workaround)

**Action:** Remove the WASM bundle to force OPA fallback

```bash
# Rename WASM bundle so it won't be found
mv /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm \
   /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm.disabled

# Restart MCP server
# Kill all processes: kill $(ps aux | grep containerization-assist-mcp | grep -v grep | awk '{print $2}')
# Server will auto-restart and use OPA binary
```

**Why This Works:**
- When `wasmPath` doesn't exist, `if (allBuiltIn && wasmPath)` is false
- Forces fallback to OPA binary
- OPA binary correctly evaluates all policies including custom ones

### Option 2: Patch the WASM Evaluation Function (Code Fix)

**File to Edit:** `/home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/dist/src/config/policy-rego.js`

**Find this code (around line 150):**
```javascript
if (!policyModule) {
    logger.debug({ fileName }, 'Policy file has no WASM entrypoint mapping, skipping');
    continue;
}
```

**Replace with:**
```javascript
if (!policyModule) {
    logger.error({ 
        fileName, 
        allPolicyPaths: policyPaths,
        builtInMappings: Object.keys(BUILT_IN_POLICY_MODULES)
    }, 'CRITICAL: Policy file has no WASM entrypoint mapping. This should not happen - allBuiltIn check should have prevented WASM usage!');
    
    // Return error instead of silently skipping
    return {
        allow: false,
        violations: [{
            rule: 'policy-wasm-mapping-error',
            category: 'system',
            message: `Policy ${fileName} cannot be evaluated in WASM mode. This is a bug - please report.`,
            severity: 'block',
        }],
        warnings: [],
        suggestions: [],
        summary: { total_violations: 1, total_warnings: 0, total_suggestions: 0 }
    };
}
```

**Why This Helps:**
- Makes the problem visible instead of silent
- Shows an error in the fix-dockerfile output
- Helps diagnose if WASM is incorrectly being used

### Option 3: Add Dynamic WASM Entrypoint Mapping (Proper Fix)

**File to Edit:** Same file, same function

**Replace the mapping check:**
```javascript
const fileName = basename(policyPath);
const policyModule = BUILT_IN_POLICY_MODULES[fileName];

if (!policyModule) {
    // Try to construct dynamic entrypoint for custom policies
    // Extract package name from filename (custom.rego -> custom_org if package is containerization.custom_org)
    const baseName = fileName.replace('.rego', '').replace(/-/g, '_');
    const dynamicEntrypoint = `${POLICY_NAMESPACE}/${baseName}/result`;
    
    logger.info({ fileName, dynamicEntrypoint }, 
        'Policy not in BUILT_IN_POLICY_MODULES, trying dynamic entrypoint');
    
    try {
        const wasmResult = wasmPolicy.evaluate(inputData, dynamicEntrypoint);
        // ... process result if successful ...
    } catch (error) {
        logger.warn({ fileName, error }, 
            'Dynamic entrypoint failed - custom policy cannot be evaluated in WASM mode');
        continue;
    }
}
```

**Why This Might Not Work:**
- Custom policies aren't compiled into the WASM bundle
- WASM bundle only contains built-in policies
- Would need to rebuild WASM bundle with custom policies included

### Option 4: Fix the allBuiltIn Check (Add Assertion)

**File to Edit:** Same file, in `loadAndMergeRegoPolicies` function

**Add this code RIGHT BEFORE the WASM path:**
```javascript
// Double-check allBuiltIn logic
if (allBuiltIn && wasmPath) {
    // Verify no custom policies snuck through
    const customPolicies = policyPaths.filter(p => 
        !Object.keys(BUILT_IN_POLICY_MODULES).includes(basename(p))
    );
    
    if (customPolicies.length > 0) {
        logger.error({
            allBuiltIn,
            customPolicies,
            allPaths: policyPaths,
            builtInModules: Object.keys(BUILT_IN_POLICY_MODULES)
        }, 'BUG DETECTED: allBuiltIn is true but custom policies exist!');
        
        // Force OPA binary usage
        logger.warn('Forcing OPA binary usage due to custom policies');
        // Skip WASM block, go directly to OPA fallback
    } else {
        // Safe to use WASM
        try {
            logger.info({ wasmPath, policyCount: policyPaths.length }, 
                'Loading pre-compiled WASM bundle for built-in policies');
            // ... existing WASM code ...
        }
    }
}
```

## Recommended Immediate Action

**Use Option 1 (Force OPA Binary):**

```bash
cd /home/runner/work/spring-petclinic/spring-petclinic

# 1. Disable WASM bundle
sudo mv /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm \
        /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm.disabled

# 2. Kill MCP server to force restart
kill $(ps aux | grep 'containerization-assist-mcp' | grep -v grep | awk '{print $2}')

# 3. Wait for server to restart
sleep 10

# 4. Test with fix-dockerfile tool
# Should now show 2 violations (built-in + custom)
```

## Verification

After applying the fix, run:
```bash
# Should show 2 violations now
containerization-assist-mcp-fix-dockerfile --path /home/runner/work/spring-petclinic/spring-petclinic/invalid.Dockerfile
```

Expected output:
```
**Policy Validation:** ❌ FAILED
  Violations: 2
    • Only Microsoft Container Registry images are allowed...
    • This is a test violation from containerization.custom_org (always-fail).
```

## Restore Original State

If you need to restore the WASM bundle:
```bash
sudo mv /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm.disabled \
        /home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm
```
