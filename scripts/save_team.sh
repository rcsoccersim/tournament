#!/bin/sh

team=$1
date=$(date +%Y-%m-%d)
#date=rc2011
user=robocup

case $# in
	1)
		sudo tar -czf ../teams/${team}-${date}.tgz --exclude-from=exclude.txt /home/${team}/
		sudo chown ${user}:${user} ../teams/${team}-${date}.tgz
		;;
	*)
		echo "Usage: save_team.sh <team>"
		echo "or './all_teams.sh save_team.sh' for all teams"
		;;
esac
