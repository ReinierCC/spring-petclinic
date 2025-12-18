# Solution: Custom Rego Policy Not Being Respected

## Root Cause

The custom rego policies in `/rego` directory are **discovered correctly** but **not evaluated** by the `fix-dockerfile` MCP tool due to **policy caching** in the MCP server process.

## Problem

The MCP server in `containerization-assist-mcp` loads and caches policies on first tool execution. If the MCP server was started before:
- The `CUSTOM_POLICY_PATH` environment variable was set, OR
- The custom policy files were created in the `/rego` directory

Then the server will have cached an empty or incomplete policy list, and subsequent tool executions will NOT re-discover the custom policies.

## Evidence

### Working Cases ✅
1. **CLI `list-policies` command**: Discovers custom policy correctly
   - This runs in a new process each time
   - Reads CUSTOM_POLICY_PATH from current environment
   
2. **Manual OPA evaluation**: Evaluates custom policy correctly  
   - Direct OPA invocation with all 4 policies produces expected violations
   - Confirms the policy syntax and logic are correct

### Failing Case ❌
1. **MCP `fix-dockerfile` tool**: Does NOT evaluate custom policy
   - Only shows 1 violation (from built-in base-images.rego)
   - Missing the custom policy violation
   - Suggests cached policy list from server startup

## Code Analysis

The caching mechanism in `src/app/orchestrator.ts`:

```typescript
// Cache the loaded policy to avoid reloading on every execution
let policyCache: RegoEvaluator | undefined;
let policyLoadPromise: Promise<void> | undefined;

async function execute(request: ExecuteRequest): Promise<Result<unknown>> {
  // Load policies once (with Promise-based guard to prevent race conditions)
  if (!policyLoadPromise) {
    policyLoadPromise = (async () => {
      const policyPaths = discoverPolicies(logger);  // ← Runs only once!
      const policyResult = await loadAndMergeRegoPolicies(policyPaths, logger);
      if (policyResult.ok) {
        policyCache = policyResult.value;  // ← Cached for all future calls
      }
    })();
  }
  await policyLoadPromise;
  // ... rest of execution
}
```

**Issue**: Once `policyLoadPromise` is set, it's never reset. If custom policies are added after the first tool execution, they won't be discovered.

## Recommended Fixes

### Option 1: Watch for Policy Changes (Best)
Add file system watching to invalidate cache when policies change:

```typescript
import { watch } from 'node:fs';

// Watch CUSTOM_POLICY_PATH for changes
if (process.env.CUSTOM_POLICY_PATH) {
  watch(process.env.CUSTOM_POLICY_PATH, (eventType, filename) => {
    if (filename && filename.endsWith('.rego')) {
      logger.info({ filename }, 'Policy file changed, invalidating cache');
      policyLoadPromise = undefined;
      policyCache = undefined;
    }
  });
}
```

### Option 2: TTL-based Cache (Good)
Invalidate cache after a time period:

```typescript
let policyCacheTimestamp: number | undefined;
const POLICY_CACHE_TTL_MS = 60000; // 1 minute

async function execute(request: ExecuteRequest): Promise<Result<unknown>> {
  const now = Date.now();
  if (policyCacheTimestamp && now - policyCacheTimestamp > POLICY_CACHE_TTL_MS) {
    policyLoadPromise = undefined;
    policyCache = undefined;
  }
  // ... rest of code
}
```

### Option 3: Environment Variable to Disable Caching (Simple)
Allow users to disable caching for development:

```typescript
const DISABLE_POLICY_CACHE = process.env.DISABLE_POLICY_CACHE === 'true';

async function execute(request: ExecuteRequest): Promise<Result<unknown>> {
  if (DISABLE_POLICY_CACHE || !policyLoadPromise) {
    policyLoadPromise = (async () => {
      // ... load policies
    })();
  }
  // ...
}
```

### Option 4: Explicit Cache Invalidation Tool (Pragmatic)
Add an MCP tool to manually invalidate the cache:

```typescript
// New tool: invalidate-policy-cache
export const invalidatePolicyCacheTool = {
  name: 'invalidate-policy-cache',
  description: 'Invalidate cached policies and reload on next tool execution',
  handler: async () => {
    policyLoadPromise = undefined;
    policyCache = undefined;
    return Success({ message: 'Policy cache invalidated' });
  }
};
```

## Workaround for Current Version

Since we're using version 1.0.2, the workaround is:

1. **Set `CUSTOM_POLICY_PATH` BEFORE starting the MCP server**
2. **Ensure custom policy files exist BEFORE first tool execution**
3. **Restart the MCP server** if policies are added/changed after startup

## Verification

After implementing fix, verify with:

```bash
# 1. Set environment variable
export CUSTOM_POLICY_PATH=/path/to/rego

# 2. Create custom policy
cat > $CUSTOM_POLICY_PATH/test.rego << 'EOF'
package containerization.test
# ... policy content
EOF

# 3. Call fix-dockerfile
npx containerization-assist-mcp ...

# 4. Verify custom violation appears in output
```

## Conclusion

The containerization-assist source code is **functionally correct** but has a **caching design limitation** that prevents custom policies from being discovered after MCP server initialization. 

**Recommendation**: Submit PR to Azure/containerization-assist with Option 1 (file watching) or Option 3 (cache disable flag) to address this issue.
