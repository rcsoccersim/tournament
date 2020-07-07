#!/bin/sh

host=$1
team=$2
user=robocup

echo Synchronizing $team to $host...

# ssh ${host} "rm -rf /home/${team}/*"
# ssh ${host} "rm -rf /home/${team}/.??*"
ssh ${host} "rm -rf /home/${team}"
rsync --recursive --compress --executability --links --exclude=.ssh --exclude=.subversion --exclude=.svn --exclude=.bash* --exclude=.profile --exclude=CVS --exclude=.viminfo --exclude=.cache --rsh=ssh /home/${team}/ ${host}:/home/${team}/
