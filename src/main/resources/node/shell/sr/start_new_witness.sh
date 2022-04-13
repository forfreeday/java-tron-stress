#!/bin/bash
total=`cat /proc/meminfo  |grep MemTotal |awk -F ' ' '{print $2}'`
xmx=`echo "$total/1024/1024*0.8" | bc |awk -F. '{print $1"g"}'`
#echo "-Xms$xmx -Xmx$xmx" >> /data/databackup/java-tron/java-tron-1.0.0/bin/java-tron.vmoptions
export LD_PRELOAD="/usr/lib64/libtcmalloc.so"

/data/databackup/java-tron/java-tron-1.0.0/bin/FullNode --witness -c /data/databackup/java-tron/config.conf --es > /data/databackup/java-tron/tron-shell.log 2>&1 & echo $! >/data/databackup/java-tron/pid.txt
#nohup  java -Xms$xmx -Xmx$xmx -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/data/databackup/java-tron/heapdump/ -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9996 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -jar /data/databackup/java-tron/java-tron.jar -p $LOCAL_WITNESS_PRIVATE_KEY --witness -c /data/databackup/java-tron/config.conf > /data/databackup/java-tron/tron-shell.log 2>&1 & echo $! >/data/databackup/java-tron/pid.txt
