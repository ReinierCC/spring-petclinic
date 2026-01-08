# How to Use Custom Rego Policies

This guide explains how to create and use custom Rego policies with the containerization-assist-mcp tool.

## Quick Start

1. **Set the environment variable** (if not already set):
   ```bash
   export CUSTOM_POLICY_PATH=/path/to/your/rego/files
   ```

2. **Create your custom policy** in a `.rego` file in that directory

3. **Restart the MCP server** to load the new policies

4. **Verify** with:
   ```bash
   npx containerization-assist-mcp list-policies --show-merged
   ```

## Directory Structure

Custom policies can be placed in one of these locations (in priority order):

1. **Custom directory via `$CUSTOM_POLICY_PATH`** (highest priority)
   - Example: `/home/runner/work/spring-petclinic/spring-petclinic/rego`
   - Set via environment variable

2. **`policies.user/` directory** (medium priority)
   - For source installations

3. **Built-in policies** (lowest priority)
   - Provided by the npm package

## Custom Policy Template

```rego
package containerization.your_namespace

import rego.v1

# Policy metadata
policy_name := "Your Policy Name"
policy_version := "1.0"
policy_category := "quality"  # or "security", "performance", "debug"

# Define violations
violations contains v if {
    # Your policy logic here
    # Example: Check if Dockerfile contains specific text
    contains(input.content, "some-forbidden-pattern")
    
    v := {
        "rule": "your-rule-id",
        "category": "quality",
        "priority": 100,  # Higher = more important
        "severity": "block",  # "block", "warn", or "suggest"
        "message": "Clear message about the violation",
        "description": "Detailed explanation of why this is a problem",
    }
}

# Define warnings (optional)
warnings contains w if {
    # Your warning logic
    w := {
        "rule": "warning-rule-id",
        "category": "performance",
        "priority": 50,
        "severity": "warn",
        "message": "Warning message",
        "description": "Why this might be a problem",
    }
}

# Define suggestions (optional)
suggestions contains s if {
    # Your suggestion logic
    s := {
        "rule": "suggestion-rule-id",
        "category": "best-practices",
        "priority": 25,
        "severity": "suggest",
        "message": "Suggestion message",
        "description": "How to improve",
    }
}

# Policy decision
default allow := false
allow if {
    count(violations) == 0
}

# Result structure (required)
result := {
    "allow": allow,
    "violations": violations,
    "warnings": warnings,
    "suggestions": suggestions,
    "summary": {
        "total_violations": count(violations),
        "total_warnings": count(warnings),
        "total_suggestions": count(suggestions),
    },
}
```

## Example: Microsoft Container Registry Policy

This example enforces using only Microsoft Container Registry images:

```rego
package containerization.microsoft_registry

import rego.v1

policy_name := "Microsoft Container Registry Only"
policy_version := "1.0"
policy_category := "quality"

# Check if input is a Dockerfile
is_dockerfile if {
    contains(input.content, "FROM ")
}

# Violation: Non-MCR images
violations contains v if {
    is_dockerfile
    # Match any FROM line
    regex.match(`(?im)FROM\s+[a-z0-9._/-]+:`, input.content)
    # But NOT mcr.microsoft.com
    not regex.match(`(?im)FROM\s+mcr\.microsoft\.com/`, input.content)
    
    v := {
        "rule": "require-microsoft-images",
        "category": "quality",
        "priority": 95,
        "severity": "block",
        "message": "Only Microsoft Container Registry images are allowed. Use mcr.microsoft.com/openjdk/jdk for Java, mcr.microsoft.com/dotnet for .NET, mcr.microsoft.com/azurelinux/base for base images.",
        "description": "Require Microsoft Container Registry images for all deployments",
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

## Input Structure

Your policies receive input in this format:

```json
{
    "content": "FROM node:20-alpine\nWORKDIR /app\n..."
}
```

For Dockerfiles, `input.content` contains the entire Dockerfile content as a string.

## Testing Your Policies

### 1. Test with OPA CLI

```bash
# Create test input
cat > test-input.json << EOF
{
  "content": "FROM docker.io/node:20-alpine\nWORKDIR /app\nCOPY . .\nCMD [\"node\", \"app.js\"]"
}
EOF

# Test your policy
opa eval \
  -d your-policy.rego \
  -i test-input.json \
  -f json \
  'data.containerization.your_namespace.result'
```

### 2. Test with containerization-assist-mcp

```bash
# List discovered policies
npx containerization-assist-mcp list-policies --show-merged

# Test on a Dockerfile
# (assuming fix-dockerfile MCP tool is available)
```

## Severity Levels

- **`block`**: Prevents deployment, must be fixed
- **`warn`**: Should be addressed, doesn't block
- **`suggest`**: Nice to have, optional improvement

## Categories

- **`security`**: Security-related issues
- **`performance`**: Performance optimizations
- **`quality`**: Code/configuration quality
- **`best-practices`**: General best practices
- **`debug`**: Debugging/testing policies

## Priority

Higher numbers = higher priority. Typical ranges:
- `90-100`: Critical issues
- `70-89`: High priority
- `50-69`: Medium priority
- `1-49`: Low priority

## Common Patterns

### Check for text in Dockerfile
```rego
contains(input.content, "text-to-find")
```

### Use regex matching
```rego
regex.match(`(?im)FROM\s+node:.*`, input.content)
```

### Check multiple conditions
```rego
violations contains v if {
    condition1
    condition2
    not condition3  # Must NOT meet this condition
    v := { ... }
}
```

## Troubleshooting

### Custom policies not showing up

1. **Check environment variable**:
   ```bash
   echo $CUSTOM_POLICY_PATH
   ```

2. **Verify policy files exist**:
   ```bash
   ls -la $CUSTOM_POLICY_PATH/*.rego
   ```

3. **Restart the MCP server**:
   Policies are cached on server startup. Kill and restart the server process.

4. **Check for syntax errors**:
   ```bash
   opa check your-policy.rego
   ```

### Violations not appearing

1. **Verify policy logic**: Test with `opa eval` directly
2. **Check input structure**: Ensure you're accessing `input.content` correctly
3. **Review severity**: Make sure you're using `"block"`, `"warn"`, or `"suggest"`

## Best Practices

1. **Start simple**: Begin with one rule, test it, then expand
2. **Use clear messages**: Help users understand what to fix
3. **Test thoroughly**: Use `opa eval` to validate logic
4. **Version your policies**: Include `policy_version` for tracking
5. **Document requirements**: Add comments explaining the policy intent
6. **Avoid false positives**: Test against real-world Dockerfiles

## References

- [Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-reference/)
- [Rego Testing](https://www.openpolicyagent.org/docs/latest/policy-testing/)
