package containerization.test_simple

import rego.v1

policy_name := "Simple Test"
policy_version := "1.0"
policy_category := "debug"

violations contains v if {
  v := {
    "rule": "simple-test-rule",
    "category": "debug",
    "priority": 999,
    "severity": "block",
    "message": "Simple test violation",
    "description": "Testing if custom policies work",
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
