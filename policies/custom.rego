package containerization.custom_org

import rego.v1

policy_name := "Custom Org Always-Fail Test"
policy_version := "1.0"
policy_category := "debug"

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

warnings := []
suggestions := []

default allow := false
allow if {
  count(violations) == 0
}

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
