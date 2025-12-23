package dockerfile.validation

import rego.v1

# Rule: Enforce allowed registries - simplified version
deny[msg] {
    input.Stages[_].Commands[_].Cmd == "from"
    from_image := input.Stages[_].Commands[_].Value[0]
    not startswith(from_image, "mcr.microsoft.com")
    not startswith(from_image, "myacrregistry.azurecr.io")
    msg := sprintf("Image '%s' is not from an allowed registry. Must be from MCR (mcr.microsoft.com) or approved ACR (myacrregistry.azurecr.io).", [from_image])
}
