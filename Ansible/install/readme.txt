Example Output:
============================================================================


🔧  Installing Ansible from repository: http://repo.example.com/ansible.repo
✅  Ansible installed successfully.

🤖  Would you like to create an Ansible user?
➡️  (y/n): y

👥  Would you like to create a new system group (system)?
➡️  (y/n): y

🔧  Creating system group: system
✅  Group system created.
✅  Added group system to the 'wheel' group for admin privileges.

🔧  Creating user: ansibleuser and adding to system group
✅  User ansibleuser created and added to group system and 'wheel'.
✅  User ansibleuser granted passwordless sudo privileges.

🔧  Setting permissions for /etc/ansible for the group: system
✅  Permissions set for /etc/ansible directory.

🔑  Would you like to generate SSH keys for the user ansibleuser?
➡️  (y/n): y

🔑  Generating SSH key pair for ansibleuser...
✅  SSH keys generated.
✅  Public key added to authorized_keys.

🚀  Setup complete!




How to Use:
============================================================================

    Save the Script: Save the script as ansible-install.sh on your RedHat or Rocky Linux server.

    Make the Script Executable: 
 
          chmod +x ansible-install.sh

    Execute the script:

         ./ansible-install.sh
