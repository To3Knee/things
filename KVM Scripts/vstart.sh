#! /bin/bash
  
VM=$1

if [ $# -eq 0 ]; then
    printf "\n"
    virsh list --all

    printf "\n"
    read -e -p "MACHINE NAME TO START: " VM
fi

printf "\n"
virsh start $VM

sleep 3

printf "\n"
virsh list --all
vdisplay
printf "\n"

exit