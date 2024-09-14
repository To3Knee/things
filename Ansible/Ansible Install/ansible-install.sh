#!/bin/bash

# Name Of Script: Ansible Installation and User Setup Script
# Developed By: To3knee
# Date: 2024-09-14
# Version: 1.2
#
# OS Recommendation:
#   - Rocky Linux: 8, 9
#   - RedHat: 8, 9
#
# This script installs Ansible, creates a user group, adds a user, manages permissions for /etc/ansible, 
# and optionally generates SSH keys for the user.

# Variables
ANSIBLE_REPO_URL=${ANSIBLE_REPO_URL:-"http://repo.example.com/ansible.repo"}  # Replace with actual repo URL
SYSTEM_GROUP=${SYSTEM_GROUP:-"system"}
USERNAME=${USERNAME:-"ansibleuser"}  # Replace with desired username

# Functions
function install_ansible() {
    # Check if Ansible is already installed
    if command -v ansible >/dev/null 2>&1; then
        echo "Ansible is already installed."
        return 0
    fi

    echo "Installing Ansible from repository: $ANSIBLE_REPO_URL"

    # Create a custom repository for Ansible
    cat <<EOL > /etc/yum.repos.d/ansible.repo
[ansible]
name=Ansible Repository
baseurl=$ANSIBLE_REPO_URL
gpgcheck=0
enabled=1
EOL

    # Install Ansible
    yum install -y ansible
    if [[ $? -eq 0 ]]; then
        echo "Ansible installed successfully."
    else
        echo "Failed to install Ansible." >&2
        exit 1
    fi
}

function create_system_group() {
    echo "Creating system group: $SYSTEM_GROUP"
    if ! grep -q "^$SYSTEM_GROUP:" /etc/group; then
        groupadd "$SYSTEM_GROUP"
        echo "Group $SYSTEM_GROUP created."
    else
        echo "Group $SYSTEM_GROUP already exists."
    fi

    # Add the system group to the wheel group
    usermod -aG wheel "$SYSTEM_GROUP"
    echo "Added group $SYSTEM_GROUP to wheel group."
}

function create_user_and_assign_group() {
    echo "Creating user: $USERNAME and adding to $SYSTEM_GROUP group"
    if ! id -u "$USERNAME" >/dev/null 2>&1; then
        useradd -m -G "$SYSTEM_GROUP,wheel" "$USERNAME"
        echo "User $USERNAME created and added to group $SYSTEM_GROUP and wheel."
    else
        echo "User $USERNAME already exists. Adding to group $SYSTEM_GROUP."
        usermod -aG "$SYSTEM_GROUP,wheel" "$USERNAME"
    fi

    # Grant sudo access to the user without password prompt (for Ansible's 'become')
    if ! grep -q "$USERNAME ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        echo "User $USERNAME granted passwordless sudo privileges."
    else
        echo "User $USERNAME already has passwordless sudo privileges."
    fi
}

function set_ansible_permissions() {
    echo "Setting permissions for /etc/ansible for the group: $SYSTEM_GROUP"
    if [[ -d /etc/ansible ]]; then
        chown -R :$SYSTEM_GROUP /etc/ansible
        chmod -R g+rwx /etc/ansible
        echo "Permissions set for /etc/ansible directory."
    else
        echo "/etc/ansible directory does not exist. Please ensure Ansible is installed."
    fi
}

function setup_ssh_keys() {
    # Ask the user if SSH keys should be created
    read -p "Would you like to create SSH keys for $USERNAME? (y/n): " create_keys

    if [[ $create_keys == "y" || $create_keys == "Y" ]]; then
        # Create the .ssh directory if it doesn't exist
        SSH_DIR="/home/$USERNAME/.ssh"
        if [[ ! -d $SSH_DIR ]]; then
            mkdir -p "$SSH_DIR"
            chown "$USERNAME:$USERNAME" "$SSH_DIR"
            chmod 700 "$SSH_DIR"
        fi

        # Generate SSH key pair
        if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
            echo "Generating SSH key pair for $USERNAME..."
            sudo -u "$USERNAME" ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N ""
            echo "SSH keys generated."
        else
            echo "SSH keys already exist for $USERNAME."
        fi

        # Ensure the public key is in authorized_keys
        if [[ ! -f "$SSH_DIR/authorized_keys" ]]; then
            cp "$SSH_DIR/id_rsa.pub" "$SSH_DIR/authorized_keys"
            chown "$USERNAME:$USERNAME" "$SSH_DIR/authorized_keys"
            chmod 600 "$SSH_DIR/authorized_keys"
            echo "Public key added to authorized_keys."
        else
            echo "authorized_keys already exists for $USERNAME."
        fi
    else
        echo "Skipping SSH key creation."
    fi
}

# Main execution
install_ansible
create_system_group
create_user_and_assign_group
set_ansible_permissions
setup_ssh_keys

echo "Setup complete."
