#! /bin/bash
  
VM=$1

if [ $# -eq 0 ]; then
    printf "\n"
    virsh list --autostart

    printf "\n"
    read -e -p "MACHINE NAME TO DISABLE AUTO START: " VM
fi

printf "\n"
virsh autostart $VM --disable

sleep 3

printf "\n"
virsh list --autostart

printf "\n"
exit