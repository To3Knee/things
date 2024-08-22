#!/bin/bash

# Variables - adjust these as necessary
KVM_SERVER_IP="<your_kvm_server_ip>"
INTERNAL_REPO_SERVER="<your_internal_repo_server>"
BASE_DIR="/var/www/html/repos"
LOG_DIR="/var/log/kvm_setup"
REPOS=("rocky/8" "rocky/9" "epel/8" "epel/9" "rhel/8" "rhel/9")
RHEL_REPOS=("rhel-8-for-x86_64-baseos-rpms" "rhel-8-for-x86_64-appstream-rpms" "rhel-9-for-x86_64-baseos-rpms" "rhel-9-for-x86_64-appstream-rpms")

# Create directories
sudo mkdir -p $BASE_DIR
sudo mkdir -p $LOG_DIR

# Install necessary packages
sudo dnf install -y libvirt libvirt-daemon-kvm qemu-kvm virt-install virt-manager httpd yum-utils createrepo rsync

# Enable and start services
sudo systemctl enable --now libvirtd
sudo systemctl enable --now httpd

# Configure Firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=libvirt
sudo firewall-cmd --reload

# Sync Rocky and EPEL repositories
for REPO in "${REPOS[@]}"; do
    echo "Syncing $REPO..."
    sudo rsync -avz $INTERNAL_REPO_SERVER:/path/to/$REPO/ $BASE_DIR/$REPO/ &>> $LOG_DIR/reposync-$REPO.log
    sudo createrepo --update $BASE_DIR/$REPO &>> $LOG_DIR/reposync-$REPO.log
done

# Sync RHEL repositories
for RHEL_REPO in "${RHEL_REPOS[@]}"; do
    echo "Syncing $RHEL_REPO..."
    sudo reposync -r $RHEL_REPO -p $BASE_DIR/rhel/${RHEL_REPO%%-*} --download-metadata --newest-only &>> $LOG_DIR/reposync-rhel.log
    sudo createrepo --update $BASE_DIR/rhel/${RHEL_REPO%%-*} &>> $LOG_DIR/reposync-rhel.log
done

# Function to validate repo sync logs
validate_reposync_logs() {
    for REPO in "${REPOS[@]}"; do
        LOGFILE="$LOG_DIR/reposync-$REPO.log"
        if grep -iq "error" $LOGFILE || grep -iq "failed" $LOGFILE || grep -iq "warning" $LOGFILE; then
            echo "Reposync encountered issues with $REPO. Check the log at $LOGFILE"
        else
            echo "$REPO reposync completed successfully."
        fi
    done

    if grep -iq "error" $LOG_DIR/reposync-rhel.log || grep -iq "failed" $LOG_DIR/reposync-rhel.log || grep -iq "warning" $LOG_DIR/reposync-rhel.log; then
        echo "Reposync encountered issues with RHEL repos. Check the log at $LOG_DIR/reposync-rhel.log"
    else
        echo "RHEL reposync completed successfully."
    fi
}

# Run validation
validate_reposync_logs

# PXE/Kickstart setup - example for a basic configuration
sudo mkdir -p /var/lib/tftpboot/pxelinux.cfg
sudo cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
sudo cp /usr/share/syslinux/menu.c32 /var/lib/tftpboot/
sudo cp /usr/share/syslinux/memdisk /var/lib/tftpboot/
sudo cp /usr/share/syslinux/mboot.c32 /var/lib/tftpboot/
sudo cp /usr/share/syslinux/chain.c32 /var/lib/tftpboot/

# Example Kickstart file for Rocky Linux 8/9 deployment
cat << EOF | sudo tee /var/www/html/kickstart/rocky8_9.ks
# System language
lang en_US.UTF-8

# Keyboard layouts
keyboard us

# System timezone
timezone America/New_York --isUtc

# Root password
rootpw --iscrypted \$6\$somehashedpassword

# Network information
network --bootproto=dhcp --device=eth0

# System authorization information
auth --useshadow --passalgo=sha512

# SELinux configuration
selinux --enforcing

# Firewall configuration
firewall --enabled --ssh

# Reboot after installation
reboot

# Installation source
url --url="http://$KVM_SERVER_IP/repos/rocky/8"

# Partitioning
zerombr
clearpart --all --initlabel

# Dynamic Partitioning Script
%pre
# Disk Size Detection
disk_size=\$(lsblk -b -d -n -o SIZE /dev/sda)

# Basic Partition Scheme
echo 'clearpart --all --initlabel' > /tmp/partitioning.ks
echo 'part /boot/efi --fstype="efi" --size=512 --ondisk=sda' >> /tmp/partitioning.ks

if [ "\$disk_size" -gt 100000000000 ]; then
  echo 'part /boot --fstype="ext4" --size=1024 --ondisk=sda' >> /tmp/partitioning.ks
  echo 'part pv.01 --size=1 --grow --ondisk=sda' >> /tmp/partitioning.ks
else
  echo 'part /boot --fstype="ext4" --size=512 --ondisk=sda' >> /tmp/partitioning.ks
  echo 'part pv.01 --size=1 --grow --ondisk=sda' >> /tmp/partitioning.ks
fi

echo 'volgroup VolGroup00 pv.01' >> /tmp/partitioning.ks
echo 'logvol / --fstype="ext4" --size=10240 --name=root --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol swap --fstype="swap" --size=2048 --name=swap --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /tmp --fstype="ext4" --size=2048 --name=tmp --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /sto --fstype="ext4" --size=8192 --name=sto --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /mnt/data --fstype="ext4" --size=8192 --name=data --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /home --fstype="ext4" --size=4096 --name=home --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /var --fstype="ext4" --size=4096 --name=var --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /var/tmp --fstype="ext4" --size=2048 --name=var_tmp --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /var/log --fstype="ext4" --size=4096 --name=var_log --vgname=VolGroup00' >> /tmp/partitioning.ks
echo 'logvol /var/log/audit --fstype="ext4" --size=2048 --name=var_log_audit --vgname=VolGroup00' >> /tmp/partitioning.ks
%end

%include /tmp/partitioning.ks

# Post-Install Configuration for Bare Metal Prep
%post --interpreter=/bin/bash
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
if [ -x /usr/bin/cloud-init ]; then
    cloud-init clean
    rm -rf /var/lib/cloud/*
fi
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/ssh/ssh_host_*
touch /.autorelabel
echo "Bare-metal preparation completed on \$(hostname)" > /root/prep_baremetal.log
%end

# Bootloader configuration
bootloader --location=mbr --append="rhgb quiet"
EOF

echo "KVM server setup complete. Repositories synced and validated. PXE and Kickstart configured."
