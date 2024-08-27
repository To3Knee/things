#! /bin/bash
  
VM=$1

if [ $# -eq 0 ]; then

    printf "\n"
    virsh list --all

    printf "\n"
    read -e -p "MACHINE NAME TO SHUTDOWN: " VM

fi

printf "\n"
virsh shutdown $VM

sleep 5

printf "\n"
virsh list --all

printf "\n"
exit