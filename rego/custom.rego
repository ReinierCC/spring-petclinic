package containerization.custom_comment_policy

import rego.v1

# Optional metadata (nice for debugging / reporting)
policy_name := "Dockerfile Comment Enforcement"
policy_version := "1.0"
policy_category := "compliance"

# -----------------------------------------------------------------------------
# Input type detection
# -----------------------------------------------------------------------------

# Basic "is this a Dockerfile?" heuristic
is_dockerfile if {
  input.content != ""
  contains(input.content, "FROM ")
}

# Keep the same style as the docs' example
input_type := "dockerfile" if {
  is_dockerfile
} else := "unknown"

# -----------------------------------------------------------------------------
# RULES
# -----------------------------------------------------------------------------

# Single rule: require verification comment
violations contains result if {
  input_type == "dockerfile"
  not has_verification_comment

  result := {
    "rule":      "require-verification-comment",
    "category":  "compliance",
    "priority":  90,
    "severity":  "block",
    "message":   "Dockerfile must contain the comment '# CREATED BY CA - VERIFIED THROUGH REGO'.",
    "description": "Require verification comment in Dockerfile",
  }
}

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------

# Check for verification comment anywhere in the Dockerfile
has_verification_comment if {
  regex.match(`(?i)#\s*CREATED BY CA - VERIFIED THROUGH REGO`, input.content)
}

# -----------------------------------------------------------------------------
# POLICY DECISION
# -----------------------------------------------------------------------------

default allow := false

allow if {
  count(violations) == 0
}

# No warnings or suggestions in this policy
warnings := []
suggestions := []

# Result structure (this is what containerization-assist expects)
result := {
  "allow":       allow,
  "violations":  violations,
  "warnings":    warnings,
  "suggestions": suggestions,
  "summary": {
    "total_violations":  count(violations),
    "total_warnings":    count(warnings),
    "total_suggestions": 0,
  },
}
