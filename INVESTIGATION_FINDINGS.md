# Investigation: Custom Rego Policy Files Not Being Respected

## Problem Statement
Custom rego policy files in `/rego` directory are not being respected when using the `fix-dockerfile` MCP tool.

## Investigation Steps

### 1. Verified Policy Discovery
✅ Running `npx containerization-assist-mcp list-policies --show-merged` correctly discovers and loads custom.rego:
```
Custom via CUSTOM_POLICY_PATH (Priority: High):
  - custom.rego

Total: 4 policy file(s)
```

### 2. Verified OPA Evaluation
✅ Tested custom.rego directly with OPA CLI:
```bash
opa eval -d rego/custom.rego -i test-input.json 'data.containerization.custom_org.result'
```
Result: custom.rego correctly generates the "always-fail" violation.

### 3. Verified Multi-Policy Evaluation  
✅ Tested all policies together (built-in + custom):
```bash
opa eval -d policies/*.rego -d rego/custom.rego -i test-input.json 'data.containerization'
```
Result: All namespaces (base_images, security, best_practices, custom_org) present and evaluated correctly.

### 4. Tested fix-dockerfile MCP Tool
❌ When calling `containerization-assist-mcp-fix-dockerfile` tool:
- With invalid.Dockerfile (docker.io registry): Shows 1 violation (from base-images.rego only)
- With MCR image (passing built-in policies): Shows 0 violations (should show 1 from custom.rego)
- **custom.rego violations are NOT included in results**

## Root Cause

The custom rego files in `/rego` are NOT being respected by the MCP tool because:

**The MCP tool runs in a separate process context that does not inherit the CUSTOM_POLICY_PATH environment variable AND the process.cwd() is not the repository directory, so policies.user/ discovery also fails.**

### Evidence:
1. `CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego` is set in the shell environment
2. CLI commands (`npx containerization-assist-mcp list-policies`) run in shell context and correctly use this variable
3. MCP tool calls (via SDK/protocol) run in a SEPARATE process without environment variables
4. Created `policies.user/` directory in repository, but MCP tool still doesn't find it (process.cwd() is not the repository path)
5. Without CUSTOM_POLICY_PATH or policies.user/ in the correct location, MCP server only loads built-in policies

### Technical Details:
- MCP Server Process: Runs from npm package installation directory
- `process.cwd()` in MCP server: Points to npm package location, NOT repository
- `policies.user/` search: Starts from process.cwd(), searches upward max 5 levels
- Repository location: `/home/runner/work/spring-petclinic/spring-petclinic`
- NPM package location: `/home/runner/.npm/_npx/*/node_modules/containerization-assist-mcp`
- Distance: Too far for upward search to find repository's policies.user/

### Code Analysis:
From `/node_modules/containerization-assist-mcp/dist/src/app/orchestrator.js`:
```javascript
export function discoverPolicies(logger) {
    const allPolicies = [];
    
    // Built-in policies (always loaded)
    const builtInPolicies = discoverBuiltInPolicies(logger);
    allPolicies.push(...builtInPolicies);
    
    // User policies from policies.user/ directory
    const userPolicies = discoverUserPolicies(logger);
    allPolicies.push(...userPolicies);
    
    // Custom policies from CUSTOM_POLICY_PATH environment variable
    const customPath = process.env[ENV_VARS.CUSTOM_POLICY_PATH];
    if (customPath) {
        const customPolicies = discoverCustomPolicies(customPath, logger);
        if (customPolicies.length > 0) {
            logger.info({ path: customPath, count: customPolicies.length }, 
                'Discovered custom policies from CUSTOM_POLICY_PATH');
            allPolicies.push(...customPolicies);
        }
    }
    
    return allPolicies;
}
```

## Solution

The issue is that the MCP tool SDK does not pass environment variables or working directory context to the MCP server process. To make custom rego policies work with MCP tools, the MCP server needs to be configured at startup, not at tool invocation time.

### Current Behavior (Not Working):
```bash
# Setting env var in shell - NOT inherited by MCP tool process
export CUSTOM_POLICY_PATH=/path/to/rego
# MCP tool call does not see this environment variable
containerization-assist-mcp-fix-dockerfile --path Dockerfile
```

### What DOES Work:
**Option 1: Using CLI Commands (Confirmed Working)**
```bash
# CLI commands run in shell context and inherit environment variables
export CUSTOM_POLICY_PATH=/home/runner/work/spring-petclinic/spring-petclinic/rego
npx containerization-assist-mcp list-policies --show-merged
# ✅ Shows: "Custom via CUSTOM_POLICY_PATH (Priority: High): custom.rego"
```

**Option 2: MCP Client Configuration (For Production Use)**
Configure the MCP client (Claude Desktop, VS Code, etc.) to start the server with environment variables:
```json
{
  "mcpServers": {
    "containerization-assist": {
      "command": "npx",
      "args": ["-y", "containerization-assist-mcp"],
      "env": {
        "CUSTOM_POLICY_PATH": "/absolute/path/to/rego/directory"
      }
    }
  }
}
```

**Option 3: Place Policies in NPM Package Location (Workaround)**
```bash
# Find npm package location
NPM_PKG=$(find ~/.npm/_npx -name "containerization-assist-mcp" -type d | head -1)

# Copy policies to policies.user/ next to the package
mkdir -p "$NPM_PKG/policies.user"
cp rego/custom.rego "$NPM_PKG/policies.user/"
```
⚠️ This is fragile - npx cache can be cleared, making policies disappear

### What Does NOT Work:
❌ **Environment Variables in Shell** - Not inherited by MCP tool process  
❌ **policies.user/ in Repository** - MCP tool's process.cwd() is not the repository  
❌ **--workspace Parameter** - Not passed through MCP tool SDK invocation

## Verification Test

To verify custom policies are loaded:
```bash
# Test 1: CLI (should include custom.rego)
npx containerization-assist-mcp list-policies --show-merged

# Test 2: Create a Dockerfile that passes all built-in policies
echo 'FROM mcr.microsoft.com/openjdk/jdk:21-ubuntu
WORKDIR /app
COPY . .
CMD ["java", "-jar", "app.jar"]' > test.Dockerfile

# Test 3: Run fix-dockerfile
# Expected: Should show "always-fail-custom-org" violation from custom.rego
# Actual (current): Shows 0 violations (custom.rego not loaded)
```

## Recommendations

1. **For Repository Users**: Copy rego/custom.rego to policies.user/custom.rego
2. **For MCP Client Configurations**: Add CUSTOM_POLICY_PATH to environment variables
3. **For Documentation**: Clarify that CUSTOM_POLICY_PATH must be configured in MCP client config, not just shell environment

## Files Involved

- `/rego/custom.rego` - Custom policy (always-fail test)
- `invalid.Dockerfile` - Test Dockerfile
- Built-in policies in `node_modules/containerization-assist-mcp/policies/`:
  - `base-images.rego`
  - `security-baseline.rego`
  - `container-best-practices.rego`
