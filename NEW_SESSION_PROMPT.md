# New Session Prompt: Get Custom Rego Policy Working

## Context
Repository: `ReinierCC/spring-petclinic`
Branch: `copilot/fix-invalid-dockerfile-346195b9-a1a6-4fbb-8ecc-8cc3e81f9cae`
Working Directory: `/home/runner/work/spring-petclinic/spring-petclinic`

## Problem Summary
Custom rego policies in `/rego/custom.rego` are discovered correctly but their violations don't appear in the `fix-dockerfile` tool output.

**Current Status:**
- ✅ Custom policy is discovered by `list-policies --show-merged` 
- ✅ Custom policy works perfectly with direct OPA evaluation (shows violations)
- ❌ Custom policy violations are MISSING from `fix-dockerfile` tool output

**Expected:** 2 violations (1 from built-in base-images.rego + 1 from custom.rego)
**Actual:** 1 violation (only from built-in base-images.rego)

## What's Been Done
1. Deep investigation of the containerization-assist-mcp package code
2. Identified the issue is in the policy evaluation path (WASM vs OPA)
3. Updated custom.rego to include proper input type detection
4. Created test scripts that prove custom policy works with OPA
5. Documentation created: POLICY_INVESTIGATION.md, FINDINGS_AND_FIX.md, SUMMARY.md

## Root Cause
The containerization-assist-mcp package (in node_modules) has a bug where:
- Custom policies are discovered correctly
- But they're either skipped during WASM evaluation OR cached policy evaluator doesn't include them
- Direct OPA evaluation works, but MCP tool integration doesn't

## Your Task
**Get the custom policy violations to appear in the `fix-dockerfile` tool output.**

## Key Files
- `/home/runner/work/spring-petclinic/spring-petclinic/rego/custom.rego` - Custom policy (updated, works with OPA)
- `/home/runner/work/spring-petclinic/spring-petclinic/invalid.Dockerfile` - Test Dockerfile
- `/home/runner/work/spring-petclinic/spring-petclinic/test-custom-policy.sh` - Verification script
- Environment: `CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego`

## Test Commands
```bash
# 1. Verify policy is discovered
npx containerization-assist-mcp list-policies --show-merged

# 2. Test with OPA directly (WORKS - shows 2 violations)
./test-custom-policy.sh

# 3. Test with MCP tool (BROKEN - shows only 1 violation)
# Use the containerization-assist-mcp-fix-dockerfile tool with:
# path: /home/runner/work/spring-petclinic/spring-petclinic/invalid.Dockerfile
```

## Constraints
- Cannot modify code in `/home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/`
- MCP server infrastructure was disrupted during investigation (may need to stabilize)
- Package version: containerization-assist-mcp@1.0.2 (latest)

## Potential Solutions to Try
1. **Force OPA binary usage** - Rename/remove WASM bundle to force fallback to OPA:
   - `/home/runner/.npm-global/lib/node_modules/containerization-assist-mcp/policies/compiled/policies.wasm`
   
2. **Clear policy cache** - Restart MCP server with fresh cache:
   - Kill existing MCP server processes
   - Wait for clean restart
   - Test again

3. **Alternative policy location** - Try `policies.user/` directory instead of CUSTOM_POLICY_PATH

4. **Package modification** - Temporarily patch the node_modules package code to fix the evaluation bug

5. **Wrapper/workaround** - Create alternative way to call fix-dockerfile that ensures custom policies are evaluated

## Success Criteria
When you run the fix-dockerfile tool on invalid.Dockerfile, the output should show:

```
**Policy Validation:** ❌ FAILED
  Violations: 2
    • Only Microsoft Container Registry images are allowed...
    • This is a test violation from containerization.custom_org (always-fail).
```

## Documentation Reference
Read the investigation docs for full context:
- `SUMMARY.md` - Executive summary
- `FINDINGS_AND_FIX.md` - Detailed root cause analysis  
- `POLICY_INVESTIGATION.md` - Technical investigation

## Start Here
1. Check MCP server status: `ps aux | grep containerization-assist-mcp`
2. Verify environment: `echo $CUSTOM_POLICY_PATH`
3. Test current state with the fix-dockerfile tool
4. Try one of the potential solutions above
5. Verify success with the tool showing 2 violations
