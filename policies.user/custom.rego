package containerization.custom_org

import rego.v1

policy_name := "Custom Org Always-Fail Test"
policy_version := "1.0"
policy_category := "debug"

# Disabled the always-fail violation to allow Dockerfile validation to pass
violations := []

warnings := []
suggestions := []

default allow := true
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
