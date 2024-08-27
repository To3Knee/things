#! /bin/bash
  
VM=$1

if [ $# -eq 0 ]; then
    printf "\n"
    virsh list --all

    printf "\n"
    read -e -p "MACHINE NAME TO AUTO START: " VM
fi

printf "\n"
virsh autostart $VM

sleep 3

printf "\n"
virsh list --autostart

printf "\n"
exit