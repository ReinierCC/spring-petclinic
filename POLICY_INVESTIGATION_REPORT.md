# Policy Violation Investigation Report

## Problem Statement
The `containerization-assist-mcp-fix-dockerfile` tool should trigger policy violations when analyzing `invalid.Dockerfile` which uses `docker.io/node:20-alpine` - a registry not allowed by the Azure registry policy.

## Expected Behavior
The azure-registry.rego policy should:
1. Detect that `FROM docker.io/node:20-alpine` violates the allowed registry list
2. Report a blocking violation
3. Show `policyValidation.passed: false`
4. Include the violation message in the output

## Actual Behavior
- `policyValidation.passed`: `true`
- `policyValidation.violations`: `[]` (empty array)
- `policyValidation.blockingViolations`: `0`
- No policy violations reported

## Investigation Process

### Test 1: Original azure-registry.rego Policy
**Location**: `policies/azure-registry.rego`  
**Logic**: Checks if FROM image starts with `mcr.microsoft.com` or `myacrregistry.azurecr.io`

**Test Command**:
```bash
containerization-assist-mcp-fix-dockerfile
  --environment production
  --path /home/runner/work/spring-petclinic/spring-petclinic/invalid.Dockerfile
  --policyPath /home/runner/work/spring-petclinic/spring-petclinic/policies/azure-registry.rego
```

**Result**: ❌ No violations reported

### Test 2: Modified azure-registry.rego (More Defensive)
**Changes**:
- Removed dependency on `input_type` detection
- Used `object.get()` for safer input access
- Inlined image extraction logic

**Result**: ❌ No violations reported

### Test 3: Always-Fail Test Policy
**Location**: `policies/test-policy.rego`  
**Logic**: Unconditionally creates a violation regardless of input

```rego
violations contains result if {
    result := {
        "rule": "test-always-fail",
        "category": "test",
        "priority": 100,
        "severity": "block",
        "message": "TEST: This policy should always trigger a violation",
        "description": "Test policy to verify policy evaluation is working",
    }
}
```

**Result**: ❌ No violations reported - **This proves policies are not being evaluated**

### Test 4: Debug Policy with Input Inspection
**Location**: `policies/debug.rego`  
**Logic**: Creates violations showing input structure

```rego
violations contains msg if {
    msg := {
        "rule": "debug-policy-trigger",
        "message": sprintf("DEBUG: Input keys: %v", [object.keys(input)]),
        ...
    }
}
```

**Result**: ❌ No violations reported - **Confirms policies are not executing**

### Test 5: Minimal Docker.io Detection
**Location**: `policies/minimal-policy.rego`  
**Logic**: Simple string match for "docker.io" in content

**Result**: ❌ No violations reported

### Test 6: Alternative Input Format (deny rule)
**Location**: `policies/simple-registry.rego`  
**Logic**: Used `deny[msg]` pattern with parsed Dockerfile structure

**Result**: ❌ No violations reported

## Tool Output Analysis

Consistent output across all tests:
```json
{
  "policyValidation": {
    "passed": true,
    "violations": [],
    "warnings": [],
    "suggestions": [],
    "summary": {
      "totalRules": 9,
      "matchedRules": 2,
      "blockingViolations": 0,
      "warnings": 0,
      "suggestions": 0
    }
  }
}
```

### Key Observations:
1. **totalRules: 9** - These appear to be built-in rules, not custom Rego policies
2. **matchedRules: 2** - Constant regardless of which policy file is specified
3. **violations**: Always empty, even with unconditional violation policies
4. **No policy evaluation errors** - Tool doesn't report any Rego syntax or evaluation errors

## Root Cause

The `containerization-assist-mcp-fix-dockerfile` tool is **not evaluating custom Rego policies** or **not capturing their violation results**.

### Possible Explanations:
1. The tool may not implement Rego policy evaluation at all
2. The `policyPath` parameter may not be connected to actual policy evaluation
3. The tool might be silently failing to load/parse/execute the Rego policies
4. The Rego evaluation might be happening but results are not being merged into the output
5. The expected input/output contract between the tool and Rego might be different than standard

## Evidence Summary

| Test Case | Expected | Actual | Status |
|-----------|----------|--------|--------|
| Azure registry policy | Violation for docker.io | No violation | ❌ FAIL |
| Always-fail policy | Unconditional violation | No violation | ❌ FAIL |
| Debug policy | Show input structure | No violation | ❌ FAIL |
| Minimal docker.io check | Violation for docker.io | No violation | ❌ FAIL |
| Built-in best practices | 4 violations | 4 violations | ✅ PASS |

## Conclusion

The `containerization-assist-mcp-fix-dockerfile` tool successfully performs built-in best practice validation but **does not execute or integrate custom Rego policies** specified via the `policyPath` parameter.

This appears to be either:
- A **bug** in the policy integration feature
- A **missing feature** where policy evaluation is not implemented
- A **configuration issue** where additional setup is required for policy evaluation

## Recommendations

1. **Tool Maintainers**: Implement or fix Rego policy evaluation integration
2. **Users**: Do not rely on custom Rego policies with this tool until the issue is resolved
3. **Alternative**: Use standalone OPA evaluation or conftest for policy validation
4. **Workaround**: Rely on built-in best practice checks only

## Files Created During Investigation

- `policies/azure-registry.rego` - Original Azure registry policy
- `policies/test-policy.rego` - Always-fail test policy
- `policies/debug.rego` - Debug policy to inspect input
- `policies/minimal-policy.rego` - Minimal docker.io detection
- `policies/simple-registry.rego` - Alternative deny[] pattern
- `DOCKERFILE_FIX_RESULTS.md` - Initial analysis results
- `POLICY_INVESTIGATION_REPORT.md` - This report

## Invalid Dockerfile Content (Test Input)

```dockerfile
# Test Dockerfile with invalid registry
FROM docker.io/node:20-alpine
WORKDIR /app
COPY . .
CMD ["node", "app.js"]
```

**This Dockerfile clearly violates the Azure registry policy** but the tool does not detect or report it.
