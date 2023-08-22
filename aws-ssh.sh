#!/bin/bash

# Get the folder path of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Extract IP and username from file content
ip=$(grep -m 1 -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$SCRIPT_DIR/ansible/inventory")
user=$(grep -m 1 "ansible_user" "$SCRIPT_DIR/ansible/inventory" | awk -F '=' '{print $2}')

# Check if either IP or username is missing
if [[ -z $ip || -z $user ]]; then
  echo "Error: IP or username not found in inventory file"
  exit 1
fi

# Connect to the target host using SSH
ssh -i ~/.ssh/aws "$user"@"$ip" 

