# tournament script for the RoboCup Soccer Simulator #

You can find a short description of the steps required to set up this script for the competition.
The original description was written by Andreas Hechenblaickner, the founder of this script.

### Requirements: ###

* I recommend using Ubuntu 10.04 LTS 64-bit
* Ruby (use apt-get install ruby-full)
* to generate flash logs: robocup2flash and rcgverconv
* to serve results and logs: apache or other web server
* of course rcssserver and all dependencies
* to generate team accounts: mkpasswd
* to synchronize team binaries: rsync

### Preparations: ###

* There should be a user 'robocup' with sudo priviliges.
* Place the tournament/ folder (content of the attached archive) in this user's home directory.
* Set /home/robocup/tournament/log/ as the apache web root.
* SSH login to all client hosts must be possible without entering passwords.
* Edit scripts/all_teams.sh and add a line for each participating team.
* Edit scripts/sync_team.sh to fit the client host names.
* Copy ~/tournament/skel/* to /etc/skel/. Files in this directory will be the content of new home directories.
* Create user accounts for all teams (see scripts below).
* Edit country in each teams team.yml file (must match flag image file in log/robocup20xx/countries/).
* Copy and adjust config files from config/robocup2010 to config/robocup20xx.
* Edit log/tournament.css and log/results.xsl if you want to modify the style of the results.

### Provided scripts: ###

- sync.sh - sync team binaries to client hosts
- start.sh - used to start matches from config files
- test-team.sh - run binary test for a single team
- scripts/add_account.sh - create team accounts with default password 'robocup'
- scripts/fix_access.sh - fixes access to files in team directories
- scripts/all_teams.sh - run a script for each team
- scripts/save_team.sh - save team binary to .tgz file

So the usual workflow to test all binaries and to start a group of matches
is:

```
 $ cd ~/tournament
 $ ./sync.sh
 $ ./start.sh --config=config/robocup2011/test.yml
 $ ./start.sh --config=config/robocup2011/<config>.yml --simulate
 $ ./start.sh --config=config/robocup2011/<config>.yml
```
