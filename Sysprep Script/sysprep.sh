#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

sysprep.parse_args() {
    [[ -n $1 ]] || {
        printf 'No arguments specified, use -h for help.\n' >&2
        exit 1
    }
    while [[ -n $1 ]]; do
        case "$1" in
            -v)
                printf 'Sysprep script for Linux. Version 1.0\n'
                shift
                [[ -n $1 ]] || exit 0
                ;;
            -h)
                printf 'Cloning preparation script for Linux systems.\n\n'
                printf 'Usage: sysprep.sh [-v ] (-h | -y [-b] [-l <log_file>] [-s])\n\n'
                printf 'Options:\n'
                printf '  -h  Display this help text.\n'
                printf '  -b  Used for firstboot (internal).\n'
                printf '  -l  Specify log file location.\n'
                printf '  -s  Shutdown on completion.\n'
                printf '  -v  Emit version header.\n'
                printf '  -y  Confirm sysprep.\n'
                exit 0
                ;;
            -b)
                FIRSTBOOT=true
                shift
                ;;
            -l)
                LOGFILE=${2:-/var/log/sysprep.log}
                shift 2
                ;;
            -s)
                SHUTDOWN=true
                shift
                ;;
            -y)
                CONFIRM=true
                shift
                ;;
            *)
                printf 'Invalid argument specified, use -h for help.\n' >&2
                exit 1
                ;;
        esac
    done
}

utils.say() {
    LOGFILE=${LOGFILE:=/var/log/sysprep.log}
    if [[ -n $LOGFILE && $LOGFILE != no ]]; then
        [[ -f $LOGFILE ]] || UMASK=027 /usr/bin/touch "$LOGFILE"
        printf '%s: %s\n' "$(date -u +%FT%TZ)" "$@" | tee -a "$LOGFILE"
    else
        printf '%s: %s\n' "$(date -u +%FT%TZ)" "$@" >&2
    fi
}

utils.error_exit() {
    utils.say "ERROR: $1"
    exit 1
}

sysprep.apt_purge() {
    vers=$(/usr/bin/ls -tr /boot/vmlinuz-* | /usr/bin/head -n -1 | /usr/bin/grep -v "$(uname -r)" | /usr/bin/cut -d- -f2-)
    debs=""
    for i in $vers; do
        debs+="linux-{image,headers,modules}-$i "
    done
    if ! /usr/bin/apt remove -qy --purge "$debs" &> /dev/null; then
        utils.error_exit "Failed to purge old kernel packages."
    fi
    /usr/bin/apt autoremove -qy --purge &> /dev/null || utils.error_exit "Failed to autoremove packages."
}

sysprep.clean_packages() {
    utils.say 'Removing old kernels.'
    if [[ $FEDORA_DERIV == true ]]; then
        if command -v dnf &> /dev/null; then
            rpms=$(/usr/bin/dnf repoquery --installonly --latest-limit=-1)
            /usr/bin/dnf remove -qy "$rpms" || utils.error_exit "Failed to remove old RPMs via dnf."
        else
            /usr/bin/package-cleanup -qy --oldkernels --count=1 || utils.error_exit "Failed to cleanup old kernels."
        fi
    elif [[ $DEBIAN_DERIV == true ]]; then
        if ! command -v purge-old-kernels &> /dev/null; then
            /usr/bin/apt install -qy byobu &> /dev/null
        fi
        /usr/bin/purge-old-kernels -qy --keep 1 &> /dev/null || sysprep.apt_purge
    fi

    utils.say 'Clearing package cache.'
    if [[ $FEDORA_DERIV == true ]]; then
        /usr/bin/dnf clean all -q || utils.error_exit "Failed to clean Fedora package cache."
        /usr/bin/rm -rf /var/cache/dnf/*
    elif [[ $DEBIAN_DERIV == true ]]; then
        /usr/bin/apt clean &> /dev/null || utils.error_exit "Failed to clean Debian package cache."
        /usr/bin/rm -rf /var/cache/apt/archives/*
    fi
}

sysprep.clean_logs() {
    utils.say 'Clearing old logs.'
    /usr/sbin/logrotate -f /etc/logrotate.conf
    /usr/bin/find /var/log -type f -regextype posix-extended -regex \
        ".*/*(-[0-9]{8}|.[0-9]|.gz)$" -delete
    /usr/bin/rm -rf /var/log/journal && /usr/bin/mkdir /var/log/journal
    /usr/bin/rm -f /var/log/dmesg.old
    /usr/bin/rm -f /var/log/anaconda/*

    utils.say 'Clearing /var/log/messages.'
    : > /var/log/messages  # Truncate /var/log/messages

    utils.say 'Clearing /var/log/syslog.'
    : > /var/log/syslog  # Truncate /var/log/syslog (for Debian-based distros)

    utils.say 'Clearing /var/log/dnf.log.'
    : > /var/log/dnf.log  # Truncate /var/log/dnf.log (for Fedora/RHEL systems)

    utils.say 'Clearing audit logs.'
    : > /var/log/audit/audit.log
    : > /var/log/wtmp
    : > /var/log/lastlog
    : > /var/log/grubby

    utils.say 'Clearing bash history for all users.'
    history -c && history -w
    /usr/bin/rm -f /home/*/.bash_history /root/.bash_history
    export HISTSIZE=0
    export HISTFILESIZE=0

    utils.say 'Clearing SSH known_hosts for all users.'
    /usr/bin/rm -f /home/*/.ssh/known_hosts

    utils.say 'Clearing DHCP leases.'
    /usr/bin/rm -f /var/lib/dhcp/*

    utils.say 'Clearing firewall logs.'
    /usr/bin/rm -rf /var/log/firewalld/*

    # Check if there are any journal logs before attempting to clear them
    if [[ -d /var/log/journal ]]; then
        utils.say 'Clearing systemd journal logs.'
        /usr/bin/journalctl --rotate
        /usr/bin/journalctl --vacuum-time=1s
        /usr/bin/rm -rf /var/log/journal/*
    else
        utils.say 'No persistent journal files found. Skipping journal cleanup.'
    fi

    return 0
}

sysprep.clean_network() {
    utils.say 'Clearing udev persistent rules.'
    /usr/bin/rm -f /etc/udev/rules.d/70*

    utils.say 'Removing MACs/UUIDs from network scripts.'

    # Handle NetworkManager configuration (if it exists)
    if [[ -d /etc/NetworkManager/system-connections/ ]]; then
        if ls /etc/NetworkManager/system-connections/* &> /dev/null; then
            /usr/bin/sed -ri '/^(mac-address|uuid)=/d' /etc/NetworkManager/system-connections/*
        else
            utils.say 'No connection profiles found in /etc/NetworkManager/system-connections/. Skipping NetworkManager cleanup.'
        fi
    else
        utils.say '/etc/NetworkManager/system-connections/ directory not found. Skipping NetworkManager configuration cleanup.'
    fi

    # Handle legacy network-scripts configuration
    if [[ $FEDORA_DERIV == true ]] || [[ -d /etc/sysconfig/network-scripts/ ]]; then
        /usr/bin/sed -ri '/^(HWADDR|UUID)=/d' /etc/sysconfig/network-scripts/ifcfg-*
    else
        utils.say '/etc/sysconfig/network-scripts/ directory not found. Skipping network-scripts cleanup.'
    fi

    return 0
}

sysprep.clean_files() {
    utils.say 'Cleaning out temp directories.'
    /usr/bin/rm -rf /tmp/*
    /usr/bin/rm -rf /var/tmp/*
    /usr/bin/rm -rf /var/cache/*

    utils.say 'Cleaning up root home directory.'
    unset HISTFILE
    : >/root/.bash_history
    /usr/bin/rm -f /root/anaconda-ks.cfg
    /usr/bin/rm -rf /root/.ssh/*
    /usr/bin/rm -rf /root/.gnupg/*
    return 0
}

sysprep.generalize() {
    utils.say 'Removing SSH host keys.'
    /usr/bin/rm -f /etc/ssh/*key*

    utils.say 'Clearing machine-id.'
    : > /etc/machine-id

    utils.say 'Removing random-seed.'
    /usr/bin/rm -f /var/lib/systemd/random-seed

    [[ -f /opt/McAfee/agent/bin/maconfig ]] && {
        utils.say 'Resetting McAfee Agent.'
        /usr/bin/systemctl stop mcafee.ma
        command -V setenforce &>/dev/null && /usr/sbin/setenforce 0
        /opt/McAfee/agent/bin/maconfig -enforce -noguid
    }

    utils.say 'Resetting hostname.'
    /usr/bin/hostnamectl set-hostname 'CHANGEME'
    return 0
}

sysprep.setup_firstboot() {
    utils.say 'Enabling sysprep firstboot service.'
    FBSERVICE=/etc/systemd/system/sysprep-firstboot.service
    [[ -f $FBSERVICE ]] || /usr/bin/cat <<'EOF' > $FBSERVICE
[Unit]
Description=Sysprep first-boot setup tasks
[Service]
Type=simple
ExecStart=/usr/local/sbin/sysprep -y -b
[Install]
WantedBy=multi-user.target
EOF
    /usr/bin/systemctl enable sysprep-firstboot
    return 0
}

sysprep.firstboot() {
    utils.say 'Running sysprep first-boot setup script.'
    [[ $DEBIAN_DERIV == true ]] && {
        /usr/bin/find /etc/ssh/*key &>/dev/null || {
            utils.say 'Regenerating SSH host keys...'
            /usr/sbin/dpkg-reconfigure openssh-server
        }
    }

    [[ $HOSTNAME == CHANGEME ]] && {
        utils.say 'Regenerating hostname and rebooting...'
        /usr/bin/hostnamectl set-hostname \
            "LINUX-$(tr -cd '[:upper:][:digit:]' < /dev/urandom | head -c 9)"
        /usr/bin/systemctl reboot
    }

    if [[ -f /var/lib/aide/aide.db.gz ]]; then
        utils.say 'Regenerating AIDE database...'
        /usr/sbin/aide --update
        /usr/bin/mv -f /var/lib/aide/aide.db{.new,}.gz
    fi

    utils.say 'Sysprep first-boot setup complete, disabling service.'
    /usr/bin/systemctl disable sysprep-firstboot
    exit 0
}

sysprep.run() {
    sysprep.parse_args "$@"

    [[ $CONFIRM == true ]] || {
        utils.say 'Confirm with -y to start sysprep.'
        exit 1
    }

    utils.say 'Beginning sysprep.'
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ $ID =~ (fedora|rhel|centos) || $ID_LIKE =~ (fedora|rhel|centos) ]]; then
        FEDORA_DERIV=true
    elif [[ $ID =~ (debian|ubuntu|mint) || $ID_LIKE =~ (debian|ubuntu|mint) ]]; then
        DEBIAN_DERIV=true
    else
        utils.error_exit "An unknown base Linux distribution was detected."
    fi

    [[ $FIRSTBOOT == true ]] && sysprep.firstboot

    utils.say 'Stopping logging and auditing daemons.'
    /usr/bin/systemctl stop rsyslog.service
    /usr/sbin/service auditd stop

    sysprep.clean_packages
    sysprep.clean_logs
    sysprep.clean_network
    sysprep.clean_files
    sysprep.generalize
    sysprep.setup_firstboot

    utils.say 'End of sysprep.'
    [[ $SHUTDOWN == true ]] && {
        utils.say 'Shutting down the system.'
        /usr/bin/systemctl poweroff
    }
    exit 0
}

# Only execute if not being sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && sysprep.run "$@"
