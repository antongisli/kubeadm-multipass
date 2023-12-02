#!/bin/bash

# Check for the correct number of arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {first-cp|ha-cp|worker}"
    exit 1
fi

# Assign input argument to a variable
type=$1

# Validate the input
if ! [[ "$type" =~ ^(first-cp|ha-cp|worker)$ ]]; then
    echo "Error: Type must be 'first-cp', 'ha-cp', or 'worker'"
    exit 1
fi

# Replace the placeholder in the cloud-init template with the provided type
sed "s/\${TYPE}/$type/g" cloud-init.yaml.tpl > cloud-init.yaml

# Launch multipass with the generated cloud-init file
multipass launch --name my-vm --cloud-init cloud-init.yaml

echo "VM launched with type: $type"
