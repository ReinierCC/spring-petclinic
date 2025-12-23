package containerization.test

import rego.v1

# Always fail policy for testing
violations contains result if {
    result := {
        "rule":      "test-always-fail",
        "category":  "test",
        "priority":  100,
        "severity":  "block",
        "message":   "TEST: This policy should always trigger a violation",
        "description": "Test policy to verify policy evaluation is working",
    }
}

default allow := false

allow if {
    count(violations) == 0
}

warnings := []
suggestions := []

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
