package dockerfile.policy

import rego.v1

# Define the allowed registries
allowed_registries := {"mcr.microsoft.com", "myacrregistry.azurecr.io"} # Add your specific ACR names here

deny[msg] if {
    # Iterate over all instructions in the Dockerfile input
    some i
    input[i].Cmd == "from"
    image_name := input[i].Value[0]

    # Check if the image name starts with an allowed registry prefix
    not is_allowed_registry(image_name)

    msg := sprintf("Image '%s' is not from an allowed container registry. Must be from MCR or an approved ACR.", [image_name])
}

# New rule: require verification comment in the Dockerfile
deny[msg] if {
    not has_verification_comment
    msg := "Dockerfile must contain the comment 'CREATED BY CA - VERIFIED THROUGH REGO'."
}

# Helper function to check if the image name belongs to an allowed registry
is_allowed_registry(image_name) if {
    some registry in allowed_registries
    startswith(image_name, registry)
}

# Helper to check the presence of the required comment
has_verification_comment if {
    some i
    input[i].Cmd == "comment"
    input[i].Value[0] == "CREATED BY CA - VERIFIED THROUGH REGO"
}
