package containerization.custom_registry  # 🚨 Custom package namespace

import rego.v1

# ==============================================================================
# 🚨 CUSTOM REGISTRY POLICY 🚨
# ==============================================================================
#
# This policy enforces custom registry rules in ADDITION to built-in policies.
# To replace built-in policies, use SKIP_BUILT_IN_POLICIES env var.
#
# Example: SKIP_BUILT_IN_POLICIES="base-images.rego"
#
# ==============================================================================

policy_name := "Custom Azure Registry Enforcement"
policy_version := "1.0"
policy_category := "compliance"

# Define the allowed registries (MCR + our custom ACR)
allowed_registries := {"mcr.microsoft.com", "myacrregistry.azurecr.io", "docker.io"}

# ==============================================================================
# INPUT TYPE DETECTION
# ==============================================================================

is_dockerfile if {
    contains(input.content, "FROM ")
}

input_type := "dockerfile" if {
    is_dockerfile
} else := "unknown"

# ==============================================================================
# RULES
# ==============================================================================

# ==============================================================================
# 🚨 CUSTOM RULE: Enforce allowed registries
# ==============================================================================
# This rule will be ACTIVE when SKIP_BUILT_IN_POLICIES includes base-images.rego

# Rule: enforce-custom-registries
violations contains result if {
    is_dockerfile
    
    # Extract FROM lines
    from_lines := [line |
        line := split(input.content, "\n")[_]
        regex.match(`(?i)^\s*FROM\s+`, line)
    ]
    
    # Check each FROM line
    some line in from_lines
    image_name := extract_image_name(line)
    not is_allowed_registry(image_name)
    
    result := {
        "rule": "enforce-custom-registries",
        "category": "compliance",
        "priority": 99,
        "severity": "block",
        "message": sprintf("🚨 CUSTOM POLICY 🚨 Image '%s' must be from allowed registries: %v", [image_name, allowed_registries]),
        "description": "Custom registry policy - allows MCR, ACR, and Docker Hub"
    }
}

# Rule: Require verification comment
violations contains result if {
    input_type == "dockerfile"
    not has_verification_comment
    
    result := {
        "rule": "require-verification-comment-CUSTOM-POLICY",
        "category": "compliance",
        "priority": 99,
        "severity": "block",
        "message": "🚨 CUSTOM POLICY TRIGGERED 🚨 Dockerfile MUST contain the comment '# CREATED BY CA - VERIFIED THROUGH REGO' to pass validation!",
        "description": "Require verification comment in Dockerfile - Reinier's Policy"
    }
}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Extract image name from FROM line
extract_image_name(from_line) := image if {
    # Remove FROM keyword and whitespace
    parts := regex.split(`\s+`, trim_space(from_line))
    count(parts) >= 2
    image := parts[1]
}

# Check if image uses an allowed registry
is_allowed_registry(image_name) if {
    some registry in allowed_registries
    startswith(image_name, registry)
}

# Check for verification comment
has_verification_comment if {
    regex.match(`(?i)#\s*CREATED BY CA - VERIFIED THROUGH REGO`, input.content)
}

# ==============================================================================
# POLICY DECISION
# ==============================================================================

# Allow if no blocking violations
default allow := false
allow if {
    count(violations) == 0
}

# No warnings or suggestions in this policy
warnings := []
suggestions := []

# Result structure (required)
result := {
    "allow": allow,
    "violations": violations,
    "warnings": warnings,
    "suggestions": suggestions,
    "summary": {
        "total_violations": count(violations),
        "total_warnings": 0,
        "total_suggestions": 0,
        "policy_name": "🚨 CUSTOM REGISTRY POLICY 🚨"
    }
}
