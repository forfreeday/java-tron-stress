#!/bin/bash

javaTronDir=java-tron
worksapce=/data/workspace/replay_workspace/server_workspace/
nodeConfig=../config

# 测试数据存放目录
data=

# 在同一个机器上部署不同端口的 FullNode 节点，一个机器上部署多个FullNode
# 节约成本
duplicateNode=true

targetProjectDir=/data/databackup/java-tron/
targetDuplicateDir=/data/databackup/java-tron-copy/

resetCode=true

superNode=(
10.40.100.110
10.40.100.111
10.40.100.114
10.40.100.115
10.40.100.116
10.40.100.117
10.40.100.118
)

fullnodenet=(
10.40.100.117
10.40.100.118
)

duplicateNodeIp=(
10.40.100.110
10.40.100.111
10.40.100.114
10.40.100.115
10.40.100.116
10.40.100.117
10.40.100.118
)

buildJavaTron() {
  echo "info: Start build java-tron"
  cd /data/workspace/replay_workspace/server_workspace/java-tron/
  sed -i "s/for (int i = 1\; i < slot/\/\*for (int i = 1\; i < slot/g" /data/workspace/replay_workspace/server_workspace/java-tron/consensus/src/main/java/org/tron/consensus/dpos/StatisticManager.java
  sed -i "s/consensusDelegate.applyBlock(true)/consensusDelegate.applyBlock(true)\*\//g" /data/workspace/replay_workspace/server_workspace/java-tron/consensus/src/main/java/org/tron/consensus/dpos/StatisticManager.java
  sed -i "s/long headBlockTime = chainBaseManager.getHeadBlockTimeStamp()/\/\*long headBlockTime = chainBaseManager.getHeadBlockTimeStamp()/g" /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/core/db/Manager.java
  sed -i "s/void validateDup(TransactionCapsule/\*\/\}void validateDup(TransactionCapsule/g" /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/core/db/Manager.java
  sed -i "s/validateTapos(trxCap)/\/\/validateTapos(trxCap)/g" /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/core/db/Manager.java
  sed -i "s/validateCommon(trxCap)/\/\/validateCommon(trxCap)/g" /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/core/db/Manager.java

  sed -i 's/ApplicationFactory.create(context);/ApplicationFactory.create(context);saveNextMaintenanceTime(context);/g' /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  sed -i 's/shutdown(appT);/shutdown(appT);mockWitness(context);/g' /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  sed -i '$d' /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  sed -i "2a `cat /data/workspace/replay_workspace/server_workspace/build_insert/FullNode_import | xargs`" /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  cat /data/workspace/replay_workspace/server_workspace/build_insert/FullNode_insert >> /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/program/FullNode.java

  sed -i "s/private volatile boolean needSyncFromPeer = true/private volatile boolean needSyncFromPeer = false/g" /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/core/net/peer/PeerConnection.java
  sed -i "s/private volatile boolean needSyncFromUs = true/private volatile boolean needSyncFromUs = false/g" /data/workspace/replay_workspace/server_workspace/java-tron/framework/src/main/java/org/tron/core/net/peer/PeerConnection.java
  # build project
  ./gradlew clean build -x test -x check
}

packageProject() {
  echo "info: package java-tron"
  rm -rf /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/

  unzip -o -d /data/workspace/replay_workspace/server_workspace/ /data/workspace/replay_workspace/server_workspace/java-tron/build/distributions/java-tron-1.0.0.zip
  sed -i '$a-XX:+HeapDumpOnOutOfMemoryError' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-XX:HeapDumpPath=/data/databackup/java-tron/heapdump/' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote.port=9996' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote.authenticate=false' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote.ssl=false' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions

  echo "info: copy java-tron.vmoptions"
  #cp /data/workspace/replay_workspace/server_workspace/java-tron.vmoptions_cms /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
  # 10G内存配置
  cp /data/workspace/replay_workspace/server_workspace/conf/duplicate/java-tron.vmoptions_cms /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
}

sendSuperNode() {
  cd $worksapce
  echo "info: send test net"
  for i in ${superNode[@]}; do
    ssh -p 22008 java-tron@$i 'cd /data/databackup/java-tron && rm -rf java-tron-1.0.0'
    tar -c java-tron-1.0.0/ |pigz |ssh -p 22008 java-tron@$i "gzip -d|tar -xC /data/databackup/java-tron/"
    scp -P 22008 /data/workspace/replay_workspace/server_workspace/conf/config.conf_$i java-tron@$i:/data/databackup/java-tron/config.conf
    scp -P 22008 /data/workspace/replay_workspace/server_workspace/stop_new.sh java-tron@$i:/data/databackup/java-tron/stop.sh
    scp -P 22008 /data/workspace/replay_workspace/server_workspace/start_new_witness.sh java-tron@$i:/data/databackup/java-tron/start.sh
    echo "info: Send java-tron.jar and config.conf and start.sh to ${i} completed"
  done

  for i in ${superNode[@]}; do
    ssh -p 22008 java-tron@$i 'source ~/.bash_profile && cd /data/databackup/java-tron && sh /data/databackup/java-tron/stop.sh'
    echo "info: Stop java-tron on ${i} completed"
  done
  backup_logname="`date +%Y%m%d%H%M%S`_backup.log"
  for i in ${superNode[@]}; do
    ssh -p 22008 java-tron@$i "mv /data/databackup/java-tron/logs/tron.log /data/databackup/java-tron/logs/$backup_logname"
    echo "info: Backup tron.log of ${i} complete"
  done

  for i in ${superNode[@]}; do
    ssh -p 22008 java-tron@$i 'rm -rf /data/databackup/java-tron/output-directory/'
    echo "info: Delete database file of ${i} completed"
    # 从目标机器本地复制，不是远程推送
    ssh -p 22008 java-tron@$i 'cp -r /data/databackup/java-tron/liteDatabase/output-directory/ /data/databackup/java-tron/'
    echo "info: Copy database file of ${i} completed"
  done
  wait

  for k in $(seq 10); do
  currentminute=`date +%M | sed -r 's/^0+//'`
  if [ x"$currentminute" = x"" ] ;then
    break;
  fi;
  remainder=$(($currentminute % 5))
  echo $remainder
  if [ $remainder = 0 ] || [ $remainder = 1 ]; then
    break
  else
    echo $currentminute
    sleep 20;
  fi;
  done

  for i in ${superNode[@]}; do
    ssh -p 22008 java-tron@$i 'source ~/.bash_profile && cd /data/databackup/java-tron && sh /data/databackup/java-tron/start.sh'
    ssh -p 22008 java-tron@$i 'find /data/databackup/java-tron/logs/ -mtime +10 -name "*" -exec rm -rf {} \;'
    echo "info: Start java-tron on ${i} completed"
  done
}

sendFullNode() {
  cd $worksapce/java-tron/
  for i in ${fullnodenet[@]}; do
    scp -P 22008 /data/workspace/replay_workspace/server_workspace/start_new_fullnode.sh java-tron@$i:/data/databackup/java-tron/start.sh
  done
}

sendDuplicateNode() {
  for i in ${duplicateNodeIp[@]}; do
    # copy duplicate node config
#    ssh -22008 -Tq java-tron@$i <<EOF
#    exit
#    EOF
    ssh -p 22008 java-tron@$i 'mkdir -p /data/databackup/java-tron-copy'
    ssh -p 22008 java-tron@$i 'cd /data/databackup/java-tron-copy && sh /data/databackup/java-tron-copy/stop.sh'
    ssh -p 22008 java-tron@$i "rm -rf /data/databackup/java-tron-copy/output-directory/"
    echo "info: Delete duplicate node file of ${i} completed"
    # 从目标机器本地复制，不是远程推送
    echo "info: Copy duplicate node file of ${i} completed"
    scp -P 22008 /data/workspace/replay_workspace/server_workspace/conf/duplicate/start_new_fullnode.sh java-tron@$i:/data/databackup/java-tron/start.sh
    scp -P 22008 /data/workspace/replay_workspace/server_workspace/conf/duplicate/stop_new.sh java-tron@$i:/data/databackup/java-tron/stop.sh
    ssh -p 22008 java-tron@$i "cp -r /data/databackup/java-tron/java-tron-1.0.0/ /data/databackup/java-tron-copy/"

    echo "info: scp duplicate config file"
    scp -P 22008 $worksapce/conf/duplicate/config.conf_$i java-tron@$i:/data/databackup/java-tron-copy/config.conf
    echo "info: Copy duplicate node of ${i} completed"
    echo "info: Copy duplicate database of ${i} completed"
    ssh -p 22008 java-tron@$i 'cp -r /data/databackup/java-tron/liteDatabase/output-directory/ /data/databackup/java-tron-copy/'

  done
  wait

  for i in ${duplicateNodeIp[@]}; do
    ssh -p 22008 java-tron@$i 'cd /data/databackup/java-tron-copy && sh /data/databackup/java-tron-copy/start.sh'
    ssh -p 22008 java-tron@$i 'find /data/databackup/java-tron-copy/logs/ -mtime +10 -name "*" -exec rm -rf {} \;'
    echo "info: Start java-tron-copy on ${i} completed"
  done
}

if [ "$resetCode" = true ]; then
  echo "reset code: "
  cd $worksapce/$javaTronDir
  git reset --hard origin/master
fi

buildJavaTron

packageProject

sendFullNode

sendSuperNode

# 发布备节点
if [ "$duplicateNode" = true ]; then
  sendDuplicateNode
fi
