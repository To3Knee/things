#!/bin/bash

# Name Of Script: Ansible Installation and User Setup Script
# Developed By: To3knee
# Date: 2024-09-14
# Version: 1.4
#
# This script installs Ansible, optionally creates a user group, adds a user, manages permissions for /etc/ansible,
# and generates SSH keys if requested.

# Variables
ANSIBLE_REPO_URL=${ANSIBLE_REPO_URL:-"http://repo.example.com/ansible.repo"}
SYSTEM_GROUP=${SYSTEM_GROUP:-"system"}
USERNAME=${USERNAME:-"ansibleuser"}

# Functions
function install_ansible() {
    # Check if Ansible is already installed
    if command -v ansible >/dev/null 2>&1; then
        echo -e "\nAnsible is already installed."
        return 0
    fi

    echo -e "\nInstalling Ansible from repository: $ANSIBLE_REPO_URL"

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
        echo -e "\nAnsible installed successfully."
    else
        echo -e "\nFailed to install Ansible." >&2
        exit 1
    fi
}

function create_system_group() {
    echo -e "\nCreating system group: $SYSTEM_GROUP"
    if ! grep -q "^$SYSTEM_GROUP:" /etc/group; then
        groupadd "$SYSTEM_GROUP"
        echo -e "Group $SYSTEM_GROUP created."
    else
        echo -e "Group $SYSTEM_GROUP already exists."
    fi

    # Add the system group to the wheel group
    usermod -aG wheel "$SYSTEM_GROUP"
    echo -e "Added group $SYSTEM_GROUP to the 'wheel' group for admin privileges."
}

function create_user_and_assign_group() {
    echo -e "\nCreating user: $USERNAME and adding to $SYSTEM_GROUP group"
    if ! id -u "$USERNAME" >/dev/null 2>&1; then
        useradd -m -G "$SYSTEM_GROUP,wheel" "$USERNAME"
        echo -e "User $USERNAME created and added to group $SYSTEM_GROUP and 'wheel'."
    else
        echo -e "User $USERNAME already exists. Adding to group $SYSTEM_GROUP."
        usermod -aG "$SYSTEM_GROUP,wheel" "$USERNAME"
    fi

    # Grant sudo access to the user without password prompt (for Ansible's 'become')
    if ! grep -q "$USERNAME ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        echo -e "User $USERNAME granted passwordless sudo privileges."
    else
        echo -e "User $USERNAME already has passwordless sudo privileges."
    fi
}

function set_ansible_permissions() {
    echo -e "\nSetting permissions for /etc/ansible for the group: $SYSTEM_GROUP"
    if [[ -d /etc/ansible ]]; then
        chown -R :$SYSTEM_GROUP /etc/ansible
        chmod -R g+rwx /etc/ansible
        echo -e "Permissions set for /etc/ansible directory."
    else
        echo -e "/etc/ansible directory does not exist. Please ensure Ansible is installed."
    fi
}

function setup_ssh_keys() {
    # Create the .ssh directory if it doesn't exist
    SSH_DIR="/home/$USERNAME/.ssh"
    if [[ ! -d $SSH_DIR ]]; then
        mkdir -p "$SSH_DIR"
        chown "$USERNAME:$USERNAME" "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi

    # Generate SSH key pair
    if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
        echo -e "\nGenerating SSH key pair for $USERNAME..."
        sudo -u "$USERNAME" ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N ""
        echo -e "SSH keys generated."
    else
        echo -e "SSH keys already exist for $USERNAME."
    fi

    # Ensure the public key is in authorized_keys
    if [[ ! -f "$SSH_DIR/authorized_keys" ]]; then
        cp "$SSH_DIR/id_rsa.pub" "$SSH_DIR/authorized_keys"
        chown "$USERNAME:$USERNAME" "$SSH_DIR/authorized_keys"
        chmod 600 "$SSH_DIR/authorized_keys"
        echo -e "Public key added to authorized_keys."
    else
        echo -e "authorized_keys already exists for $USERNAME."
    fi
}

# Main execution

# Install Ansible first, as it is always required
install_ansible

# Ask if the user wants to create an Ansible user
echo -e "\nWould you like to create an Ansible user?"
read -p "(y/n): " create_ansible_user
if [[ $create_ansible_user == "y" || $create_ansible_user == "Y" ]]; then

    # Ask if the user wants to create a system group
    echo -e "\nWould you like to create a new system group ($SYSTEM_GROUP)?"
    read -p "(y/n): " create_system_group
    if [[ $create_system_group == "y" || $create_system_group == "Y" ]]; then
        create_system_group
    else
        echo -e "\nSkipping system group creation."
    fi

    # Create the user and assign to group
    create_user_and_assign_group

    # Set permissions for /etc/ansible
    set_ansible_permissions

    # Ask if the user wants to create SSH keys
    echo -e "\nWould you like to generate SSH keys for the user $USERNAME?"
    read -p "(y/n): " create_ssh_keys
    if [[ $create_ssh_keys == "y" || $create_ssh_keys == "Y" ]]; then
        setup_ssh_keys
    else
        echo -e "\nSkipping SSH key creation."
    fi
else
    echo -e "\nSkipping Ansible user creation."
fi

echo -e "\nSetup complete!"
