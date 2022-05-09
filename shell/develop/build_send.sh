#!/bin/bash
WORK_PATH=/tmp
JAVA_TRON=/data/workspace/replay_workspace/server_workspace/java-tron
IS_RESET_VERSION=true

echo "Start build java-tron"
if [[ $IS_RESET_VERSION=true ]]; then
  cd /data/workspace/replay_workspace/server_workspace/java-tron/
  git reset --hard origin/master
fi

# 禁用参与度
#sed -i "s/for (int i = 1\; i < slot/\/\*for (int i = 1\; i < slot/g" /data/workspace/replay_workspace/server_workspace/java-tron/consensus/src/main/java/org/tron/consensus/dpos/StatisticManager.java
#sed -i "s/consensusDelegate.applyBlock(true)/consensusDelegate.applyBlock(true)\*\//g" /data/workspace/replay_workspace/server_workspace/java-tron/consensus/src/main/java/org/tron/consensus/dpos/StatisticManager.java

#替换StatisticManager.java
modifyConsensus(){
  cp /$WORK_PATH/StatisticManager.java $JAVA_TRON//consensus/src/main/java/org/tron/consensus/dpos/StatisticManager.java
  cp /$WORK_PATH/StateManager.java $JAVA_TRON/consensus/src/main/java/org/tron/consensus/dpos/StateManager.java
  cp /$WORK_PATH/DposService.java $JAVA_TRON/consensus/src/main/java/org/tron/consensus/dpos/DposService.java
}

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
./gradlew clean build -x test -x check
rm -rf /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/

unzip -o -d /data/workspace/replay_workspace/server_workspace/ /data/workspace/replay_workspace/server_workspace/java-tron/build/distributions/java-tron-1.0.0.zip
sed -i '$a-XX:+HeapDumpOnOutOfMemoryError' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
sed -i '$a-XX:HeapDumpPath=/data/databackup/java-tron/heapdump/' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
sed -i '$a-Dcom.sun.management.jmxremote' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
sed -i '$a-Dcom.sun.management.jmxremote.port=9996' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
sed -i '$a-Dcom.sun.management.jmxremote.authenticate=false' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
sed -i '$a-Dcom.sun.management.jmxremote.ssl=false' /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
cp /data/workspace/replay_workspace/server_workspace/java-tron.vmoptions_cms /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions

#----------------

testnet=(
10.40.100.110
10.40.100.111
10.40.100.114
10.40.100.115
10.40.100.116
10.40.100.117
10.40.100.118
)

echo "start send java-tron jar"

for i in ${testnet[@]}; do
  echo "start IP: " $i

  #ssh -p 22008 java-tron@$i 'mv /data/databackup/java-tron/java-tron-1.0.0/lib/framework-1.0.0.jar /tmp/framework-1.0.0.jar-bak'
  #ssh -p 22008 java-tron@$i 'mv /data/databackup/java-tron-duplicate/java-tron-1.0.0/lib/framework-1.0.0.jar /tmp/framework-1.0.0.jar-bak'
  ssh -p 22008 java-tron@$i 'mv /data/databackup/java-tron/java-tron-1.0.0/lib/consensus-1.0.0.jar /tmp/consensus-1.0.0.jar-bak'
  ssh -p 22008 java-tron@$i 'mv /data/databackup/java-tron-duplicate/java-tron-1.0.0/lib/consensus-1.0.0.jar /tmp/consensus-1.0.0.jar-bak'
  scp -P 22008  /tmp/consensus-1.0.0.jar  java-tron@$i:/data/databackup/java-tron/java-tron-1.0.0/lib/
  scp -P 22008  /tmp/consensus-1.0.0.jar  java-tron@$i:/data/databackup/java-tron-duplicate/java-tron-1.0.0/lib/
done
