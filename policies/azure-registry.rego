package containerization.registry

import rego.v1

# ==============================================================================
# Azure Container Registry Policy
# ==============================================================================
#
# This policy enforces:
# 1. Only MCR and specific ACR registries are allowed
# 2. Dockerfile must contain verification comment
#
# ==============================================================================

policy_name := "Azure Registry Enforcement"
policy_version := "1.0"
policy_category := "compliance"

# Define the allowed registries
allowed_registries := {"mcr.microsoft.com", "myacrregistry.azurecr.io"}

# ==============================================================================
# INPUT TYPE DETECTION
# ==============================================================================

# Simple detection: if it contains a FROM, treat as Dockerfile
is_dockerfile if {
    input.content != ""
    contains(input.content, "FROM ")
}

input_type := "dockerfile" if {
    is_dockerfile
} else := "unknown"

# ==============================================================================
# RULES
# ==============================================================================

# Rule: Enforce allowed registries
violations contains result if {
    # Check if input has content (works with both input.content and raw input)
    content := object.get(input, "content", "")
    content != ""
    contains(content, "FROM")

    # Extract FROM lines
    from_lines := [line |
        line := split(content, "\n")[_]
        regex.match(`(?i)^\s*FROM\s+`, line)
    ]

    # Check each FROM line
    some line in from_lines
    
    # Extract image name more robustly
    trimmed := trim_space(line)
    parts := regex.split(`\s+`, trimmed)
    count(parts) >= 2
    lower(parts[0]) == "from"
    image_name := parts[1]
    
    # Check if not from allowed registry
    not is_allowed_registry(image_name)

    result := {
        "rule":      "enforce-azure-registries",
        "category":  "compliance",
        "priority":  95,
        "severity":  "block",
        "message":   sprintf("Image '%s' is not from an allowed registry. Must be from MCR (mcr.microsoft.com) or approved ACR (myacrregistry.azurecr.io).", [image_name]),
        "description": "Enforce Azure Container Registry or MCR images only",
    }
}

# Rule: Require verification comment
# violations contains result if {
#     input_type == "dockerfile"
#     not has_verification_comment
# 
#     result := {
#         "rule":      "require-verification-comment",
#         "category":  "compliance",
#         "priority":  90,
#         "severity":  "block",
#         "message":   "Dockerfile must contain the comment '# CREATED BY CA - VERIFIED THROUGH REGO'",
#         "description": "Require verification comment in Dockerfile",
#     }
# }

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Extract image name from a FROM line
# NOTE: This assumes the form: FROM <image> [AS name]
# If you use FROM with flags like --platform, you may want to make this more robust.
extract_image_name(from_line) := image if {
    line := trim_space(from_line)
    parts := regex.split(`\s+`, line)

    count(parts) >= 2
    lower(parts[0]) == "from"

    image := parts[1]
}

# Check if image uses an allowed registry
is_allowed_registry(image_name) if {
    some registry in allowed_registries
    startswith(image_name, registry)
}

# Check for verification comment anywhere in the Dockerfile
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

# Result structure (required by containerization-assist)
result := {
    "allow":       allow,
    "violations":  violations,
    "warnings":    warnings,
    "suggestions": suggestions,
    "summary": {
        "total_violations":  count(violations),
        "total_warnings":    0,
        "total_suggestions": 0,
    },
}
