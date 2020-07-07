#!/bin/sh

case $# in
	1)
		sudo deluser $1
		sudo rm -r /home/$1
		;;
	*)
		echo "Usage: remove_account.sh <account>"
esac
