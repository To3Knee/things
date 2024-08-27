#!/bin/bash
  
CYN="\e[96m"
WHT="\e[97m"
NON="\e[0m"

function showvnc() {

# SHOW VNC DISPLAY PORT INFORMATION FOR RUNNING VMS
NVM=$(virsh list | grep '[0-9]\+' | awk '{ print $2 }')

for name in ${NVM[*]}
  do
    VD=$(virsh domdisplay ${name}  | grep -Eo '[0-9]+$')
    while [ ${#VD} -ne 2 ]; do VD="0"${VD}; done
    printf "${WHT}VNC DISPLAY PORT: ${CYN}59${VD} - ${name} \n${NON}"
  done

exit

}

showvnc

exit