#!/bin/bash

#
# script to upload data (LUA scripts) over the air to an ESP chip
# which is running the telnet server. See matrix.py for an example
#
# Original script by Blue: http://www.esp8266.com/viewtopic.php?f=22&t=6744
#

if [ -z "$1$2" ]; then
  echo "Usage: $0 [file] [esp8266 telnet server ip address] [port]"
  exit 1
fi

port=${3-23}

delay=0.25
file=`basename $1`
(k=1;echo "file.remove(\"$file\")";sleep $delay;echo "file.open(\"$file\",\"w\")";sleep $delay; while IFS='' read -r line;do echo "print($k);file.writeline([[""${line//]/] }""]])"; k=$((k+1)); sleep $delay; done < $1;echo "file.close()"; sleep 1; echo "node.restart()"; )|netcat -v $2 $port
