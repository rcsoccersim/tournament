#!/bin/sh

host=$1
year=$2
month=$3
user=$(whoami)

case $# in
    3)
        ssh ${user}@${host} -f "mkdir --parents /home/${user}/tournament/log/archive/${year}/${month}/"
        scp -r /home/${user}/tournament/log/${year}${month}* ${user}@${host}:/home/${user}/tournament/log/archive/${year}/${month}/
        rm -r /home/${user}/tournament/log/${year}${month}*
        ;;
    *)
        echo "Usage: $(basename $0) <host> <year> <month>" 1>&2
esac
