# Rego Policy Quick Reference

This document provides a quick reference for the Rego policies applied to the Spring PetClinic Dockerfile.

## Policy File: `rego/test.rego`

### Policy Summary

| Policy | Status | Description |
|--------|--------|-------------|
| Container Registry Restriction | ✅ PASSED | All base images must come from approved registries |
| Verification Comment | ✅ PASSED | Dockerfile must contain verification comment |

## Policy Details

### 1. Container Registry Restriction Policy

**Purpose**: Ensure all container images are pulled from trusted, approved container registries.

**Allowed Registries**:
- `mcr.microsoft.com` (Microsoft Container Registry)
- `myacrregistry.azurecr.io` (Azure Container Registry)

**Implementation**:
```rego
allowed_registries := {"mcr.microsoft.com", "myacrregistry.azurecr.io"}

deny[msg] if {
    some i
    input[i].Cmd == "from"
    image_name := input[i].Value[0]
    not is_allowed_registry(image_name)
    msg := sprintf("Image '%s' is not from an allowed container registry...", [image_name])
}
```

**Current Compliance**:
- Base image: `mcr.microsoft.com/openjdk/jdk:17-ubuntu` ✅
- Registry: `mcr.microsoft.com` (allowed) ✅

**Example Violations**:
```dockerfile
# ❌ This would FAIL the policy
FROM ubuntu:22.04

# ❌ This would FAIL the policy
FROM docker.io/library/openjdk:17

# ✅ This PASSES the policy
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
```

### 2. Verification Comment Policy

**Purpose**: Ensure Dockerfiles have been validated and approved through the Rego policy system.

**Required Comment**: `CREATED BY CA - VERIFIED THROUGH REGO`

**Implementation**:
```rego
deny[msg] if {
    not has_verification_comment
    msg := "Dockerfile must contain the comment 'CREATED BY CA - VERIFIED THROUGH REGO'."
}

has_verification_comment if {
    some i
    input[i].Cmd == "comment"
    input[i].Value[0] == "CREATED BY CA - VERIFIED THROUGH REGO"
}
```

**Current Compliance**:
- Comment present on line 1 of Dockerfile ✅
- Exact text matches requirement ✅

**Example Implementation**:
```dockerfile
# ✅ This PASSES the policy
# CREATED BY CA - VERIFIED THROUGH REGO
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
...

# ❌ This would FAIL the policy (missing comment)
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
...

# ❌ This would FAIL the policy (incorrect text)
# Created by Container Assistant
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
...
```

## Validation Commands

### Using Conftest

Install Conftest:
```bash
# macOS
brew install conftest

# Linux
wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/
```

Run validation:
```bash
conftest test Dockerfile --policy rego/
```

Expected output when all policies pass:
```
PASS: Dockerfile
```

Expected output when policies fail:
```
FAIL: Dockerfile
- Image 'ubuntu:22.04' is not from an allowed container registry...
- Dockerfile must contain the comment 'CREATED BY CA - VERIFIED THROUGH REGO'.
```

### Using OPA (Open Policy Agent)

Install OPA:
```bash
# macOS
brew install opa

# Linux
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
sudo mv opa /usr/local/bin/
```

Test policy:
```bash
# Parse Dockerfile to structured format
docker run --rm -v $(pwd):/app aquasec/dockerfile-parser parse Dockerfile > dockerfile.json

# Test with OPA
opa eval --data rego/test.rego --input dockerfile.json "data.dockerfile.policy.deny"
```

## Modifying Policies

### Adding New Registries

Edit `rego/test.rego` and add to the `allowed_registries` set:

```rego
allowed_registries := {
    "mcr.microsoft.com",
    "myacrregistry.azurecr.io",
    "newregistry.example.com"  # Add new registry here
}
```

### Adding New Policy Rules

Add new rules to `rego/test.rego`:

```rego
# Example: Require LABEL for maintainer
deny[msg] if {
    not has_maintainer_label
    msg := "Dockerfile must include LABEL maintainer"
}

has_maintainer_label if {
    some i
    input[i].Cmd == "label"
    contains(input[i].Value[0], "maintainer")
}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Validate Dockerfile

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Conftest
        run: |
          wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
          tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
          sudo mv conftest /usr/local/bin/
      
      - name: Validate Dockerfile
        run: conftest test Dockerfile --policy rego/
```

### Azure DevOps

```yaml
- task: CmdLine@2
  displayName: 'Install Conftest'
  inputs:
    script: |
      wget https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz
      tar xzf conftest_0.45.0_Linux_x86_64.tar.gz
      sudo mv conftest /usr/local/bin/

- task: CmdLine@2
  displayName: 'Validate Dockerfile'
  inputs:
    script: 'conftest test Dockerfile --policy rego/'
```

## Policy Compliance Checklist

Before building and deploying Docker images, ensure:

- [ ] Dockerfile uses approved base images from allowed registries
- [ ] Dockerfile contains the required verification comment
- [ ] `conftest test` passes without errors
- [ ] Policy file (`rego/test.rego`) is in version control
- [ ] Policy validation is part of CI/CD pipeline
- [ ] Team members are trained on policy requirements

## References

- [Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-reference/)
- [Conftest Documentation](https://www.conftest.dev/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

## Troubleshooting

### Policy Test Fails with "command not found"

Install Conftest or OPA as described in the Validation Commands section.

### Policy Always Passes Even with Wrong Image

Ensure you're testing the correct Dockerfile path and the policy directory is correct:
```bash
conftest test ./Dockerfile --policy ./rego/
```

### Adding Registry Doesn't Take Effect

After modifying `rego/test.rego`, clear any caches and rerun the validation:
```bash
rm -rf .conftest/
conftest test Dockerfile --policy rego/
```

## Support

For questions or issues with Rego policies:
1. Review this quick reference
2. Check the [CONTAINERIZATION_REPORT.md](CONTAINERIZATION_REPORT.md)
3. Consult the [Open Policy Agent documentation](https://www.openpolicyagent.org/docs/)
