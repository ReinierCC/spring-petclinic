package containerization.dockerfile

import rego.v1

# Simplified registry enforcement
violations contains msg if {
    # Try to get content from input
    content := input.content
    
    # Check if it's a Dockerfile
    contains(content, "FROM ")
    
    # Extract the FROM line
    lines := split(content, "\n")
    from_line := [l | l := lines[_]; contains(l, "FROM")]
    
    # Check if any FROM line uses docker.io
    some line in from_line
    contains(line, "docker.io")
    
    msg := {
        "rule": "no-docker-io-registry",
        "category": "compliance",
        "priority": 95,
        "severity": "block",
        "message": "Docker.io registry is not allowed. Use mcr.microsoft.com or myacrregistry.azurecr.io instead.",
        "description": "Enforce Azure registries only"
    }
}

default allow := false

allow if {
    count(violations) == 0
}

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
