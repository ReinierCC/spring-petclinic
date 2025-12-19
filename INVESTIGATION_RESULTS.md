# Fix-Dockerfile Tool Investigation Results

## Objective
Test the `fix-dockerfile` tool with a custom rego policy to verify that the `policyPath` parameter works correctly.

## Test Setup

### Files Used
1. **invalid.Dockerfile** - A simple Dockerfile using docker.io registry:
   ```dockerfile
   # Test Dockerfile with invalid registry
   FROM docker.io/node:20-alpine
   WORKDIR /app
   COPY . .
   CMD ["node", "app.js"]
   ```

2. **rego/custom.rego** - A custom policy that ALWAYS fails:
   - Package: `containerization.custom_org`
   - Violation message: "This is a test violation from containerization.custom_org (always-fail)."
   - Severity: "block"
   - Expected behavior: Should ALWAYS produce a violation for ANY Dockerfile

## Test Execution

### Test 1: Using file path
```
Tool: containerization-assist-mcp-fix-dockerfile
Parameters:
  - path: /home/runner/work/spring-petclinic/spring-petclinic/invalid.Dockerfile
  - policyPath: /home/runner/work/spring-petclinic/spring-petclinic/rego/custom.rego
```

**Result:** ❌ FAILED to use custom policy

### Test 2: Using dockerfile content
```
Tool: containerization-assist-mcp-fix-dockerfile
Parameters:
  - dockerfile: <content of invalid.Dockerfile>
  - policyPath: /home/runner/work/spring-petclinic/spring-petclinic/rego/custom.rego
```

**Result:** ❌ FAILED to use custom policy

## Actual Behavior

Both test executions showed:
- Policy Validation: ❌ FAILED
- Violations: 1
- Violation message: "Only Microsoft Container Registry images are allowed. Use mcr.microsoft.com/openjdk/jdk for Java, mcr.microsoft.com/dotnet for .NET, mcr.microsoft.com/cbl-mariner for base images."

## Expected Behavior

The tool should have:
1. Loaded the custom policy from `/home/runner/work/spring-petclinic/spring-petclinic/rego/custom.rego`
2. Evaluated the Dockerfile against that policy
3. Reported the violation: "This is a test violation from containerization.custom_org (always-fail)."

## Conclusion

**The `policyPath` parameter is NOT being respected by the fix-dockerfile tool.**

The tool is using a built-in/default policy instead of the custom policy specified in the `policyPath` parameter. This is a bug in the tool implementation - it should honor the `policyPath` parameter when provided.

## Recommendation

The fix-dockerfile tool needs to be updated to:
1. Check if `policyPath` parameter is provided
2. Load and evaluate the custom policy from that path
3. Use the custom policy results instead of or in addition to built-in policies
