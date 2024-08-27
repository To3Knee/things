#! /bin/bash
  
VM=$1

if [ $# -eq 0 ]; then

    printf "\n"
    virsh list --all

    printf "\n"
    read -e -p "MACHINE NAME TO DELETE: " VM

fi

echo "THIS WILL PERMENENTLY DELETE THE MACHINE"

read -p "ARE YOU SURE? (y/n) " yn
case $yn in
    [yY] ) printf "\nUndefine and Delete...\n";;
    [nN] ) printf "\nExiting...\n"; exit;;
       * ) printf "\nInvalid Response. Exiting.\n"; exit 1;;
esac

    virsh destroy $VM
    virsh undefine $VM --nvram 2>/dev/null
    rm -f /sto/kvms/machines/$VM.img
    rm -f /sto/kvms/machines/$VM.qcow2
    rm -f /var/log/libvirt/qemu/$VM.log

printf "\n>>> MACHINE DELETED <<< \n\n"

printf "Listing Machine Images...\n\n"
ls -1 --color=always /sto/kvms/machines/*.img 2>/dev/null
ls -1 --color=always /sto/kvms/machines/*.qcow2 2>/dev/null

printf "\n\nCurrent Status...\n\n"
virsh list --all

printf "\n\n"
exit