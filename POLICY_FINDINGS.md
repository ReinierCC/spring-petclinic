# Custom Rego Policy Investigation Findings

## Problem Statement
Custom Rego policy files in the `/rego` directory were being discovered but not respected when running `fix-dockerfile`.

## Investigation Summary

### What Works
1. ✅ `npx containerization-assist-mcp list-policies --show-merged` correctly discovers custom policies
2. ✅ OPA command-line evaluation correctly evaluates custom policies
3. ✅ Policy merging logic in the MCP server code is correct
4. ✅ Custom policies are properly structured with the correct namespace format

### Root Cause
**The containerization-assist-mcp MCP server loads and caches policies once when it first starts up.**

When the MCP server was started (via GitHub Copilot Agent), it loaded the available policies into a cache. At that time, the custom policies in `/rego` did not exist yet. When custom policies were later added to the `/rego` directory, the MCP server continued using its cached policy list, which did not include the new custom policies.

### Evidence
1. Server process (PID 2860) was started at 20:02 before custom policies existed
2. Custom policies were created later during investigation
3. `list-policies` command (which runs fresh each time) correctly showed custom policies
4. `fix-dockerfile` tool (which uses the cached MCP server) only showed built-in policy violations
5. After killing the MCP server process, it needed to restart to pick up the new policies

### Solution
**Restart the containerization-assist-mcp MCP server after adding new custom policies.**

The MCP server must be restarted for it to discover and load newly added custom policies. Once restarted, it will:
1. Discover all policies (built-in + custom)
2. Load and merge them using OPA binary (since custom policies are present)
3. Evaluate all policies when tools like `fix-dockerfile` are called

### Technical Details

#### Policy Discovery Process
The orchestrator discovers policies in this order (higher priority last):
1. Built-in policies (from npm package)
2. User policies (from `policies.user/` directory)  
3. Custom policies (from `$CUSTOM_POLICY_PATH` environment variable)

#### Policy Loading
- If ALL policies are built-in → Use pre-compiled WASM bundle (fast, no OPA required)
- If ANY custom policies → Use OPA binary to evaluate all policies together

#### Policy Caching
From `orchestrator.js`:
```javascript
let policyCache;
let policyLoadPromise;

if (!policyLoadPromise) {
    policyLoadPromise = (async () => {
        const policyPaths = discoverPolicies(logger);
        // Load and cache policies...
    })();
}
```

The policies are loaded ONCE on first tool execution and cached for the lifetime of the MCP server process.

### Testing Custom Policies

To test that custom policies are working:

1. Ensure custom policies exist in the directory specified by `$CUSTOM_POLICY_PATH`
2. Restart the containerization-assist-mcp MCP server
3. Run `npx containerization-assist-mcp list-policies --show-merged` to verify discovery
4. Run tools like `fix-dockerfile` and check that custom policy violations appear

### Example Custom Policy Structure

Custom policies must follow this format:

```rego
package containerization.custom_namespace

import rego.v1

policy_name := "Custom Policy Name"
policy_version := "1.0"
policy_category := "quality"  # or "security", "performance", etc.

violations contains v if {
  # Policy logic here
  v := {
    "rule": "rule-id",
    "category": "quality",
    "priority": 100,
    "severity": "block",  # or "warn", "suggest"
    "message": "Violation message",
    "description": "Detailed description",
  }
}

default allow := false
allow if {
  count(violations) == 0
}

result := {
  "allow": allow,
  "violations": violations,
  "warnings": [],
  "suggestions": [],
  "summary": {
    "total_violations": count(violations),
    "total_warnings": 0,
    "total_suggestions": 0,
  },
}
```

## Conclusion

Custom Rego policies ARE supported and work correctly when the MCP server is properly restarted after adding them. The issue was a caching/timing problem, not a fundamental bug in the policy evaluation system.
