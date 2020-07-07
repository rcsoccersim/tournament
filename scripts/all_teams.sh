#!/bin/sh

script=$1

if test -e $script; then
	./$script kickofftug
	./$script helios
	./$script dainamite
	./$script brainstormers
else
	echo $script not found.
fi
