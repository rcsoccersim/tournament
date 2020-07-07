#!/bin/sh

team=$1
user=robocup
config_dir=config/robocup2011

if [ "$2" != "--nosync" ]; then
	cd /home/${user}/tournament && ./scripts/fix_access.sh ${team}
	cd /home/${user}/tournament && ./sync.sh ${team}
fi

cp ${config_dir}/test_template.yml ${config_dir}/test_${team}.yml
echo "  - ${team}" >> ${config_dir}/test_${team}.yml
./start.sh --config=${config_dir}/test_${team}.yml
rm ${config_dir}/test_${team}.yml
