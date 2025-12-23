package containerization.debug

import rego.v1

# Debug: Always add a violation to see if policy is being evaluated
violations contains msg if {
    msg := {
        "rule": "debug-policy-trigger",
        "category": "debug",
        "priority": 100,
        "severity": "block",
        "message": sprintf("DEBUG: Policy IS being evaluated. Input keys: %v", [object.keys(input)]),
        "description": "Debug rule to verify policy evaluation"
    }
}

# Also try to capture content
violations contains msg if {
    content := object.get(input, "content", "NOT_FOUND")
    msg := {
        "rule": "debug-content-check",
        "category": "debug",  
        "priority": 99,
        "severity": "block",
        "message": sprintf("DEBUG: Content value: %v", [content]),
        "description": "Debug content"
    }
}

default allow := false
allow if { count(violations) == 0 }
warnings := []
suggestions := []

result := {
    "allow": allow,
    "violations": violations,
    "warnings": warnings,
    "suggestions": suggestions,
    "summary": {
        "total_violations": count(violations),
        "total_warnings": 0,
        "total_suggestions": 0
    }
}
