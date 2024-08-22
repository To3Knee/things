# System language
lang en_US.UTF-8

# Keyboard layouts
keyboard us

# System timezone
timezone America/New_York --isUtc

# Root password (replace with your encrypted password)
rootpw --iscrypted $6$somehashedpassword

# Network information
network --bootproto=dhcp --device=eth0

# System authorization information
auth --useshadow --passalgo=sha512

# SELinux configuration
selinux --enforcing

# Firewall configuration
firewall --enabled --ssh

# Do not configure X Window System
skipx

# Reboot after installation
reboot

# Installation source (adjust the URL to match your environment)
url --url="http://192.168.1.10/rocky"

# Clear all partitions and create a new disk label
zerombr
clearpart --all --initlabel

# Dynamic partitioning script
%pre
# Check disk size and dynamically adjust partition sizes
disk_size=$(lsblk -b -d -n -o SIZE /dev/sda)

# Create a basic partition scheme
echo 'clearpart --all --initlabel' > /tmp/partitioning.ks
echo 'part /boot/efi --fstype="efi" --size=512 --ondisk=sda' >> /tmp/partitioning.ks

if [ "$disk_size" -gt 100000000000 ]; then
  # Large disk (greater than 100GB)
  echo 'part /boot --fstype="ext4" --size=1024 --ondisk=sda' >> /tmp/partitioning.ks
  echo 'part pv.01 --size=1 --grow --ondisk=sda' >> /tmp/partitioning.ks
else
  # Smaller disk (less than 100GB)
  echo 'part /boot --fstype="ext4" --size=512 --ondisk=sda' >> /tmp/partitioning.ks
  echo 'part pv.01 --size=1 --grow --ondisk=sda' >> /tmp/partitioning.ks
fi

# Create Volume Group
echo 'volgroup VolGroup00 pv.01' >> /tmp/partitioning.ks

# Logical Volumes (adjust sizes based on available disk space)
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

# Include the dynamically generated partitioning scheme
%include /tmp/partitioning.ks

# Use the raw image created in KVM to populate the root partition
%pre
# Download the VM image and write it to disk
curl -o /tmp/image.raw http://192.168.1.10/images/rocky9.4-baremetal-template.raw
dd if=/tmp/image.raw of=/dev/VolGroup00/root bs=4M status=progress
%end

# Post installation script (optional customization)
%post
# Ensure proper file labeling for SELinux
touch /.autorelabel
echo "Deployment completed on $(hostname)" > /root/deployment.log
%end

# Bootloader configuration
bootloader --location=mbr --append="rhgb quiet"
