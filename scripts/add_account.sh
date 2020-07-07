#!/bin/sh

user=robocup
password=robocup

case $# in
	1)
		sudo useradd -m -s /bin/bash -p $(mkpasswd --hash=md5 $password) $1
		sudo chown $1:$user /home/$1
		sudo chmod o-rx /home/$1
		sudo chmod g+w /home/$1

		echo "Added account ${1}."
		;;
	*)
		echo "Usage: add_account.sh <account>"
		echo "or './all_teams.sh add_account.sh' for all teams"
esac
