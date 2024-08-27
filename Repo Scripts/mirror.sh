#!/bin/bash
  
sync_root="/sto/sync"
repos_base_dir="/sto/index/repo/rockylinux"

# Start Sync (if base exists)
if [[ -d "$repos_base_dir" ]] ; then

# http://mirror.siena.edu/rocky
rsync  -avSHP --log-file=${sync_root}/rsync.log --progress --delete --exclude-from=${sync_root}/exclude.txt rsync://mirror.cs.princeton.edu/rocky "${repos_base_dir}" --delete-excluded

#http://mirror.phx1.us.spryservers.net/rockylinux
#rsync  -avSHP --log-file=${sync_root}/rsync.log --progress --delete --exclude-from=${sync_root}/exclude.txt rsync://mirror.phx1.us.spryservers.net/rockylinux "${repos_base_dir}" --delete-excluded


  # Download Rocky 8 Repository Key
  if [[ -e "${repos_base_dir}"/RPM-GPG-KEY-rockyofficial ]]; then

      # Reset Root Permissions
      chown -R root.root /sto/index/repo
      find /sto/index/repo/ -type d -exec chmod 755 {} \;
      find /sto/index/repo/ -type f -exec chmod 644 {} \;
      tail -n 1 ${sync_root}/rsync.log | cut -c '1-19' > ${sync_root}/last.txt
      SYNCTIME=$(cat ${sync_root}/last.txt)
      sed -i 's|Repo Mirror.*|Repo Mirror Last Update\*\*: '"${SYNCTIME}"'\_\<\/sub\>  |' /sto/index/README.md

  exit
  else

      wget -P ${repos_base_dir} https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-rockyofficial

      # Reset Root Permissions
      chown -R root.root //sto/index/repo
      find /sto/index/repo/ -type d -exec chmod 755 {} \;
      find /sto/index/repo/ -type f -exec chmod 644 {} \;
      tail -n 1 ${sync_root}/rsync.log | cut -c '1-19' > ${sync_root}/last.txt
      SYNCTIME=$(cat ${sync_root}/last.txt)
      sed -i 's|Repo Mirror.*|Repo Mirror Last Update\*\*: '"${SYNCTIME}"'\_\<\/sub\>  |' /sto/index/README.md

  fi

fi
