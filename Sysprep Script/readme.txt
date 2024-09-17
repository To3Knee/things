
** THANK YOU EDDIE CARSWELL!  your orginal sysprep is the foundation for this modified script ***


1. Make the Script Executable:

Before running a script, ensure it has executable permissions. If the script is saved as sysprep.sh, you can make it executable using the chmod command:

bash:

chmod +x sysprep.sh

2. Running the Script Directly:

Now you can run the script by invoking it with ./ if it's in the current directory. You need to pass the necessary arguments (for example, -y to confirm sysprep execution).

bash:

./sysprep.sh -y

3. Example Arguments:

    -y: Confirms running the sysprep.
    -b: Used for the first boot setup.
    -l <log_file>: Specifies a log file to store output.
    -s: Shuts down the system when the script finishes.
    -v: Displays the version information.
    -h: Displays the help message.

Example Use Cases:
1. Basic Run with Confirmation (-y):

To confirm sysprep execution and perform the cleanup, you would run:

bash:

./sysprep.sh -y

2. Specify a Log File (-l):

If you want to specify a custom log file to capture the output:

bash:

./sysprep.sh -y -l /path/to/logfile.log

3. Run with Shutdown (-y -s):

If you want the system to shut down after sysprep:

bash:

./sysprep.sh -y -s

4. First Boot Setup (-b):

To run the script for first boot tasks (you typically use this internally, triggered by the system's startup process):

bash:

./sysprep.sh -y -b

5. Display Help (-h):

If you need to view the help message:

bash:

./sysprep.sh -h

Note:

For more advanced usage, you can combine multiple flags like -y, -s, and -l to customize how the script behaves.





Key Features:

    MAC Address and UUID Clearing:
        MAC addresses and UUIDs are cleared from the relevant network configuration files (NetworkManager and network-scripts).
        The system will regenerate these dynamically upon reboot.

    IP Address Handling:
        Static IP: If set, it remains unchanged.
        Dynamic IP (DHCP): The system will request a new IP address from the DHCP server upon restart.

    Complete Cleanup:
        Logs, SSH keys, bash history, and other sensitive data are cleared.
        The script ensures that no sensitive machine-specific information is retained, preparing the system for cloning.

    Firstboot Setup:
        After reboot, the system will run the sysprep first-boot setup, which regenerates SSH keys and the hostname.