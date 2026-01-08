# Final Summary: Custom Rego Policy Investigation

## Problem Statement

Custom rego policy files in `/rego` directory are discovered by `list-policies` command but NOT evaluated by `fix-dockerfile` MCP tool.

## Verification Results

### Test 1: ✅ Policy Discovery Works
```bash
$ npx containerization-assist-mcp list-policies --show-merged
Custom via CUSTOM_POLICY_PATH (Priority: High):
  - custom.rego
```
**Result:** Custom policy IS discovered

### Test 2: ✅ Manual OPA Evaluation Works
```bash
$ opa eval -d base-images.rego -d ... -d custom.rego -i test-input.json 'data.containerization'
```
**Result:** 
- Base images violations: 1
- Custom policy violations: 1  
- Custom violation message: "This is a test violation from containerization.custom_org (always-fail)."

### Test 3: ❌ MCP Tool Evaluation Fails
```bash
$ containerization-assist-mcp-fix-dockerfile --path invalid.Dockerfile
```
**Result:**
```
Policy Validation: ❌ FAILED
  Violations: 1
    • Only Microsoft Container Registry images are allowed...
```
**Missing:** The custom policy violation

## Root Cause Analysis

### Primary Issue: Policy Caching
The MCP server caches policies on first tool execution (see `src/app/orchestrator.ts:238-240`):

```typescript
let policyCache: RegoEvaluator | undefined;
let policyLoadPromise: Promise<void> | undefined;
```

Once loaded, policies are **never reloaded**. If the MCP server starts before:
- CUSTOM_POLICY_PATH is set, OR  
- Custom policy files are created

Then custom policies will NOT be included in the cache.

### Secondary Factors

1. **Version Issues**: Published version 1.0.2 vs dev version 1.1.0-dev.1
   - Active development on policy path resolution in feature branches
   - Branches `thgamble/policytest` and `thgamble/loading` contain extensive debugging

2. **Path Resolution Bugs**: Fixed in feature branches but not yet released
   - Built-in policy path resolution was incorrect (4 levels vs 3 levels)
   - See `POLICY_PATH_RESOLUTION_FIX.md` in branch `thgamble/policytest`

3. **Process Isolation**: MCP server may not inherit environment variables
   - CUSTOM_POLICY_PATH must be set BEFORE server starts
   - No mechanism to reload policies after environment changes

## Upstream Investigation

Checked Azure/containerization-assist repository:

### Active Feature Branches
- `thgamble/policytest`: Policy loading investigation and fixes
- `thgamble/loading`: Knowledge and policy loader refactoring

### Key Commits (Not Yet in Main)
- `78047cc`: Debug policy discovery code
- `8647187`: Fix policy path resolution depth
- `e529194`: Fix ESM path resolution for policies
- `ce345b3`: Investigation summary document

### Conclusion
The containerization-assist team is **actively investigating and fixing** policy loading issues. The problems are documented in feature branches but not yet merged to main or released.

## Recommendations

### Short Term (Workaround)
1. Ensure CUSTOM_POLICY_PATH is set BEFORE MCP server starts
2. Ensure custom policy files exist BEFORE first tool execution
3. Restart MCP server if policies change

### Medium Term (This Repository)
Document the limitation in README:

```markdown
## Custom Policy Limitations

Custom policies must be available BEFORE the MCP server starts.  
The server caches policies on first tool execution and does not reload them.

If you add or modify custom policies:
1. Restart the MCP server
2. Clear any cached policy evaluation results
```

### Long Term (Upstream PR)
Contribute fix to Azure/containerization-assist:

**Option A**: File System Watching
```typescript
import { watch } from 'node:fs';

if (process.env.CUSTOM_POLICY_PATH) {
  watch(process.env.CUSTOM_POLICY_PATH, (eventType, filename) => {
    if (filename?.endsWith('.rego')) {
      policyLoadPromise = undefined;
      policyCache = undefined;
    }
  });
}
```

**Option B**: Cache Invalidation Flag
```typescript
const DISABLE_POLICY_CACHE = process.env.DISABLE_POLICY_CACHE === 'true';

if (DISABLE_POLICY_CACHE) {
  policyLoadPromise = undefined;
  policyCache = undefined;
}
```

**Option C**: TTL-Based Cache
```typescript
const POLICY_CACHE_TTL = 60000; // 1 minute
let cacheTimestamp: number;

if (Date.now() - cacheTimestamp > POLICY_CACHE_TTL) {
  policyLoadPromise = undefined;
  policyCache = undefined;
}
```

## Files Created

1. `INVESTIGATION_FINDINGS.md` - Detailed investigation notes
2. `SOLUTION.md` - Proposed solutions and workarounds
3. `test-custom-policy.sh` - Test script to verify custom policy evaluation
4. `FINAL_SUMMARY.md` - This file

## Verification Against GitHub Repository

**Confirmed:**
- ✅ Policy discovery logic is correct (v1.0.2 and dev)
- ✅ Policy merging logic is correct
- ✅ OPA evaluation works correctly
- ✅ Custom policy support exists and should work
- ❌ Policy caching prevents runtime policy changes
- ⚠️ Active development ongoing in feature branches (not yet released)

## Answer to Problem Statement

> "find out why the custom rego files in /rego are not being respected"

**Answer:** Custom rego files ARE discovered and CAN be evaluated correctly. However, the MCP server caches policies on first execution and never reloads them. If custom policies are added after the server starts, they will not be evaluated by tools.

> "verify if there's incorrect code in https://github.com/Azure/containerization-assist/tree/main"

**Answer:** The main branch code is functionally correct for custom policy evaluation. However:
1. Policy caching design prevents runtime policy changes (limitation, not bug)
2. Active fixes in progress for path resolution issues (feature branches)
3. No released version includes the latest policy loading improvements

## Next Steps

1. ✅ Investigation complete
2. ✅ Root cause identified  
3. ✅ Solutions proposed
4. ⏳ Consider submitting upstream PR
5. ⏳ Monitor feature branches for release
