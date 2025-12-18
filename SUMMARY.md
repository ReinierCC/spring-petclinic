# Task Completion Summary

## Tasks Completed

### 1. ✅ Call `npx containerization-assist-mcp list-policies --show-merged`

**Result**: Successfully executed and confirmed custom policies are discovered.

```
📋 Discovered Policies:

  Built-in (Priority: Low):
    - base-images.rego
    - container-best-practices.rego
    - security-baseline.rego

  Custom via CUSTOM_POLICY_PATH (Priority: High):
    - custom.rego

  Total: 4 policy file(s)

✅ Policies merged successfully
📦 Loaded 4 policy file(s)
```

**Conclusion**: The CLI correctly discovers and loads the custom.rego file from CUSTOM_POLICY_PATH environment variable.

---

### 2. ✅ Call fix-dockerfile on invalid.Dockerfile (without custom agent)

**Command Executed**: `containerization-assist-mcp-fix-dockerfile`

**Result**: Tool executed successfully, but only showed 1 violation (from built-in base-images.rego), not 2 violations as expected.

**Expected Violations**:
1. base-images.rego: "Only Microsoft Container Registry images are allowed..."
2. custom.rego: "This is a test violation from containerization.custom_org (always-fail)"

**Actual Violations**:
1. base-images.rego: "Only Microsoft Container Registry images are allowed..." ✅
2. custom.rego: **NOT SHOWN** ❌

---

### 3. ✅ Find out why custom rego files in /rego are not being respected

**Investigation Performed**: Comprehensive analysis using OPA CLI, code review, and testing.

**Root Cause Identified**:

The custom rego policy files in `/rego` are **NOT being respected** when using MCP tools because:

1. **Environment Variable Isolation**: The MCP tool runs in a separate process that does NOT inherit the `CUSTOM_POLICY_PATH` environment variable set in the shell.

2. **Working Directory Mismatch**: The MCP server's `process.cwd()` points to the npm package installation directory (`~/.npm/_npx/*/node_modules/containerization-assist-mcp`), not the repository directory (`/home/runner/work/spring-petclinic/spring-petclinic`).

3. **Policy Discovery Limitation**: The `policies.user/` directory search starts from `process.cwd()` and searches upward only 5 levels, which is insufficient to reach the repository directory.

**Evidence**:

| Test | Command Type | Custom Policies Loaded? |
|------|--------------|------------------------|
| list-policies | CLI (shell process) | ✅ YES |
| fix-dockerfile | MCP tool (separate process) | ❌ NO |
| OPA direct eval | Manual test | ✅ YES |

**Technical Details**:

- When running `npx containerization-assist-mcp list-policies`, the command runs in the shell's process with access to all environment variables.
- When calling the MCP tool via SDK (`containerization-assist-mcp-fix-dockerfile`), the MCP server runs in a separate process without environment inheritance.
- The MCP protocol does not pass shell environment variables to the server process.
- The custom.rego policy works correctly when loaded (verified with OPA CLI) but is simply not being loaded by the MCP tool.

---

## Why This Matters

The custom.rego file contains an "always-fail" test policy:

```rego
# Always emit a violation, for any input (Dockerfile, K8s, whatever)
violations contains v if {
  v := {
    "rule":      "always-fail-custom-org",
    "category":  "debug",
    "priority":  999,
    "severity":  "block",
    "message":   "This is a test violation from containerization.custom_org (always-fail).",
    "description": "If you see this, custom.rego is being evaluated.",
  }
}
```

This policy should **always** produce a violation, regardless of the Dockerfile content. The fact that it's not showing up in MCP tool results proves that custom policies are not being loaded.

---

## Workarounds and Solutions

### For Development/Testing (What Works Now):
✅ **Use CLI commands**: `npx containerization-assist-mcp list-policies`  
✅ **Use OPA directly**: `opa eval -d policies/ -d rego/ ...`

### For Production (What Needs Configuration):
⚙️ **Configure MCP Client**: Add CUSTOM_POLICY_PATH to MCP server startup config

Example for Claude Desktop/VS Code:
```json
{
  "mcpServers": {
    "containerization-assist": {
      "command": "npx",
      "args": ["-y", "containerization-assist-mcp"],
      "env": {
        "CUSTOM_POLICY_PATH": "/absolute/path/to/rego"
      }
    }
  }
}
```

### What Does NOT Work:
❌ Setting `export CUSTOM_POLICY_PATH` in shell (not inherited)  
❌ Creating `policies.user/` in repository (wrong working directory)  
❌ Passing `--workspace` parameter (not supported in tool invocation)

---

## Files Created

1. **INVESTIGATION_FINDINGS.md** - Detailed technical analysis with code snippets and evidence
2. **policies.user/custom.rego** - Copy of custom policy (for testing, but doesn't work without MCP config)
3. **SUMMARY.md** - This file

---

## Recommendations

1. **Document the limitation**: Update repository README to explain that custom policies require MCP client configuration.

2. **Add MCP config example**: Provide a sample MCP client configuration file showing how to set CUSTOM_POLICY_PATH.

3. **Consider alternative approaches**:
   - Could the MCP server discover policies relative to the workspace path instead of process.cwd()?
   - Could there be a tool parameter to specify policy directory?
   - Could the tool read a .containerization-rc config file from the working directory?

4. **For immediate testing**: Use CLI commands (`npx containerization-assist-mcp`) which correctly load custom policies.

---

## Conclusion

✅ **Task 1 Complete**: Successfully ran list-policies and confirmed custom.rego is discovered  
✅ **Task 2 Complete**: Called fix-dockerfile on invalid.Dockerfile  
✅ **Task 3 Complete**: Identified why custom rego files are not respected

**Root Cause**: MCP tool process isolation prevents environment variable inheritance and working directory context propagation.

**Impact**: Custom organizational policies cannot be enforced when using MCP tools without proper MCP client configuration.

**Next Steps**: Configure the MCP client (not the shell) with CUSTOM_POLICY_PATH to enable custom policy enforcement.
