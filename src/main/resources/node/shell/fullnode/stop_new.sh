#!/bin/bash
count=1
while [ $count -le 60 ]; do
  pid=`ps -ef |grep org.tron.program.FullNode | grep "java-tron-copy/" | grep -v grep |awk '{print $2}'`
  if [ -n "$pid" ]; then
    kill -9 $pid
    echo "kill -15 java-tron, counter $count"
    sleep 1
  else
    echo "java-tron killed"
    break
  fi
  count=$[$count+1]
  if [ $count -ge 60 ]; then
    kill -9 $pid
  fi
done
