#!/usr/bin/env bash

# This is meant to be executed periodically. It will check if the application is
# running. If it's not, it will start it.

# on crontab:
#    * * * * * /bin/bash -l -c '/path/to/watchdog/watchdog.sh'

app="myapp"
user="myuser"
dir="/home/$user/$app/current"
log="$dir/log/$app.log"

# test proof of life
alive="$dir/tmp/alive"
mtime=$(ls -l --time-style=+%s $alive | awk '{print $6}')
let "last = $(date +%s) - 60"
[ -f $alive ] && [ $mtime -gt $last ] && exit

erlopts="-boot $dir/boot/start -config $dir/boot/sys -env ERL_LIBS $dir/lib"
cmd="iex --erl \"$erlopts\" --name $app@localhost --detached"

echo "Running: $cmd" >> $log

$cmd 2>&1 >> $log

# To connect (interactive elixir):
#         iex --remsh "$app@localhost" --sname connector
