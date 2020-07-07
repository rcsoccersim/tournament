#!/bin/sh

cd scripts

if [ "$1" = "" ]; then
	date
	./all_teams.sh fix_access.sh
	./all_teams.sh sync_team.sh
	date
else
	./fix_access.sh $1
	./sync_team.sh $1
fi

