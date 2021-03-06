#!/bin/bash
# Helper script for reimaging a server.
# Author: Giuseppe Lavagetto
# Copyright (c) 2014 the Wikimedia Foundation
set -e
set -u
SLEEPTIME=60
FORCE=0
NOCLEAN=0
NOREBOOT=0

function log  {
    echo "$@"
}

function clean_puppet {
    nodename=${1}
    log "cleaning puppet certificate for ${nodename}"
    puppet cert clean ${nodename}
    # An additional, paranoid check.
    if puppet cert list --all | fgrep -q ${nodename}; then
        log "unable to clean puppet cert, please check manually"
        log "Maybe you need to use the -n switch?"
        exit 1
    fi
    log "cleaning puppet facts cache for ${nodename}"
    /usr/local/sbin/puppetstoredconfigclean.rb ${nodename}
}

function clean_salt {
    nodename=${1}
    force_yes=${2}
    log "cleaning salt key cache for ${nodename}"
    # delete the key only if it has been accepted already, we are going to
    # ask confirmation later about unaccepted keys
    if salt-key --list accepted | fgrep -q ${nodename}; then
        if [ ${force_yes} -eq 1 ]; then
            salt-key -y --delete ${nodename}
        else
            salt-key --delete ${nodename}
        fi
    fi
    # salt-key --delete above exits 0 regardless, double check
    if salt-key --list accepted | fgrep -q ${nodename}; then
        log "unable to clean salt key, please check manually"
        log "Maybe you need to use the -n switch?"
        exit 1
    fi
}

function sign_puppet {
    nodename=${1}
    force_yes=${2}
    log "Seeking the Puppet certificate to sign"
    while true; do
        res=$(puppet cert list | sed -ne "s/\"$nodename\"//p")
        if [ "x${res}" == "x" ]; then
            #log "cert not found, sleeping for ${SLEEPTIME}s"
            echo -n "."
            sleep $SLEEPTIME
            continue
        fi
        echo "+"
        if [ ${force_yes} -eq 0 ]; then
            echo "We have found a key for ${nodename} " \
                 "with the following fingerprint:"
            echo "$res"
            echo -n "Can we go on and sign it? (y/N) "
            read choice
            echo
            if [ "x${choice}" != "xy" ]; then
                log "Aborting on user request."
                exit 1
            fi
        fi
        puppet cert -s ${nodename}
        break
    done
}

function sign_salt {
    nodename=${1}
    force_yes=${2}
    log "Seeking the SALT node key to add"
    log "This is the time to start a puppet run on the host."
    while true; do
        if ! salt-key --list unaccepted | fgrep -q ${nodename}; then
            echo -n "."
            sleep $SLEEPTIME
            continue
        fi;
        echo "+"
        if [ ${force_yes} -eq 1 ]; then
            salt-key -y -a ${nodename}
        else
            salt-key -a ${nodename}
        fi
        break
    done
}

function set_pxe_and_reboot {
    mgmtname=${1}
    if [ -z "$IPMI_PASSWORD" ]; then
	    echo "WARNING: IPMI_PASSWORD not found. Assuming bash, do: "
	    echo "HISTCONTROL=ignoreboth<enter>"
	    echo "<space>export IPMI_PASSWORD='supersecretpass'"
	    echo "WARNING: Continuing without auto rebooting the box"
	    return
    fi
    export IPMI_PASSWORD
    ipmitool -I lanplus -H ${mgmtname} -U root -E chassis bootdev pxe
    ipmitool -I lanplus -H ${mgmtname} -U root -E chassis power cycle
}

function enable_and_run_puppet {
    nodename=${1}
    log "Enabling puppet"
    ssh -i /root/.ssh/install_new -o "UserKnownHostsFile=${hostsfile}" -o "GlobalKnownHostsFile=/dev/null" ${nodename} "puppet agent --enable"
    log "Spawning the first puppet run as well"
    ssh -q -i /root/.ssh/install_new -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" -o "GlobalKnownHostsFile=/dev/null" ${nodename} "puppet agent -t" > ${nodename}.puppetrun.log 2>&1 &
    log "The first puppet run is ongoing, you can see what the result is in the file ${nodename}.puppetrun.log"
}


function usage {
    echo "Usage: $0 [-y][-r][-n][-s SECONDS] <nodename> <mgmtname>"; exit 1;
}

## Main script

while getopts "yrns:" option; do
    case $option in
        y)
            FORCE=1
            ;;
        r)
            NOREBOOT=1
            ;;
        n)
            NOCLEAN=1
            ;;
        s)
            SLEEPTIME=${OPTARG}
            ;;
        *)
            usage
            ;;
esac
done
shift $((OPTIND-1))
nodename=${1:-}
mgmtname=${2:-}
test -z ${nodename} && usage
test -z ${mgmtname} && usage
log "Preparing reimaging of node ${nodename}"

if [ $NOCLEAN -eq 0 ]; then
    clean_puppet $nodename
    clean_salt $nodename $FORCE
fi;
test $NOREBOOT -eq 0 && set_pxe_and_reboot $mgmtname
sign_puppet $nodename $FORCE
sign_salt $nodename $FORCE

log "Node ${nodename} is now signed and both puppet and salt should work."
