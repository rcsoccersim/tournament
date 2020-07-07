#!/bin/sh

team=$1
user=robocup

case $# in
  1)
    sudo chown $team:$user --recursive /home/$team
    sudo chmod ug+r --recursive /home/$team
    # find /home -type d -print0 | xargs -0 sudo chmod +x
    sudo chmod g+x /home/$team
    sudo chmod 775 /home/$team/start
    sudo chmod 775 /home/$team/kill
    sudo chmod 644 /home/$team/team.yml
    sudo chown $user:$user /home/$team/team.yml
    ;;
  *)
    echo "Usage: fix_access.sh <team>"
    echo "or './all_teams.sh fix_access.sh' for all teams"
    ;;
esac
