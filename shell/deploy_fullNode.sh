#!/bin/bash
##############################################################
#
# 构建java-tron压测环境
#   1.构建SR节点
#   2.构建FullNode节点
#   3.构建FullNode-duplicate 副本节点
#   4.构建 java-tron-stress 压测客户端
#
#
##############################################################

# 构建参数
WORKSPACE=/data/java-tron-stress1
javaTronDir=java-tron
## 重置分支代码修改
CLONE_CODE=false
RESET_CODE=true
STRESS_GIT_REPOSITORY='https://github.com/forfreeday/java-tron-stress.git'
TEST_NODE_GIT_REPOSITORY='https://github.com/forfreeday/java-tron-testnode.git'
JAVA_TRON_GIT_REPOSITORY='https://github.com/tronprotocol/java-tron.git'
STRESS_PROJECT=java-tron-stress
TEST_NODE_PROJECT=java-tron-testnode
JAVA_TRON_PROJECT=java-tron
## 特定功能，写在特点分支上，通过指定分支开启功能
## 指定使用：低参与度功能
BRANCH_PARTICIPATION='stress/minParticipation'
## 指定使用：手动分叉功能
BRANCH_FORKED='stress/forked'

# 服务部署
## java-tron节点远端目录
targetProjectDir=/data/databackup/java-tron/
## 配置文件

# 数据库
# 数据库备份到节点机器上
DATABASE_BACKUP=true
# 使用本地备份数据库，开启后不会从中控节点传输数据库
useDatabaseBackup=true
databaseBackupDir=$targetProjectDir/databaseBackup

# 副本节点
# 作用：FullNode 的不同端口节点，用于部署一个机器上部署多个FullNode，使用修改端口后的配置文件，代码相同
duplicateNode=true
# java-tron 副本节点远端目录
targetDuplicateDir=/data/databackup/java-tron-duplicate/

# 部署witness
witnessNode=(
10.40.100.110
10.40.100.111
10.40.100.114
10.40.100.115
10.40.100.116
10.40.100.117
10.40.100.118
)

# FullNode 节点列表
fullnodenet=(
10.40.100.117
10.40.100.118
)

# FullNode 备用节点列表，端口不同的FullNode
duplicateNodeIp=(
10.40.100.110
10.40.100.111
10.40.100.114
10.40.100.115
10.40.100.116
10.40.100.117
10.40.100.118
)

if [[ ! -d $WORKSPACE ]]; then
  mkdir -p $WORKSPACE
  cd $WORKSPACE
fi

cloneCode() {
#  if [[ $CLONE_CODE ]]; then
#    if [[ ! -d $WORKSPACE/$javaTronDir ]]; then
#      git clone $GIT_REPOSITORY
#    else
#      echo "info: java-tron is exists."
#    fi
#  fi
  if [[ ! -d $WORKSPACE/$TEST_NODE_PROJECT ]]; then
    cd $WORKSPACE
    git clone $TEST_NODE_GIT_REPOSITORY
  fi
  $WORKSPACE/$TEST_NODE_PROJECT/gradlew clean build -x test

  if [[ ! -d $WORKSPACE/$STRESS_PROJECT ]]; then
    #mkdir -p $WORKSPACE/STRESS_PROJECT
    cd $WORKSPACE/
    git clone $STRESS_GIT_REPOSITORY
  fi
  $WORKSPACE/$STRESS_PROJECT/gradlew clean build -x test

  if [[ ! -d $WORKSPACE/$JAVA_TRON_PROJECT ]]; then
      cd $WORKSPACE/
      git clone $JAVA_TRON_GIT_REPOSITORY
  fi
}

# 构建FullNode，禁用部分功能
buildFullNode() {
echo 1
}

buildFullNode() {
  echo "info: Start build java-tron"
  cd $WORKSPACE/$javaTronDir/
  if [[ $RESET_CODE = true ]]; then
    git reset --hard origin/master
  fi

  sed -i "s/for (int i = 1\; i < slot/\/\*for (int i = 1\; i < slot/g" $WORKSPACE/java-tron/consensus/src/main/java/org/tron/consensus/dpos/StatisticManager.java
  sed -i "s/consensusDelegate.applyBlock(true)/consensusDelegate.applyBlock(true)\*\//g" $WORKSPACE/server_workspace/java-tron/consensus/src/main/java/org/tron/consensus/dpos/StatisticManager.java
  sed -i "s/long headBlockTime = chainBaseManager.getHeadBlockTimeStamp()/\/\*long headBlockTime = chainBaseManager.getHeadBlockTimeStamp()/g" $WORKSPACE/java-tron/framework/src/main/java/org/tron/core/db/Manager.java
  sed -i "s/void validateDup(TransactionCapsule/\*\/\}void validateDup(TransactionCapsule/g" $WORKSPACE/java-tron/framework/src/main/java/org/tron/core/db/Manager.java
  sed -i "s/validateTapos(trxCap)/\/\/validateTapos(trxCap)/g" $WORKSPACE/java-tron/framework/src/main/java/org/tron/core/db/Manager.java
  sed -i "s/validateCommon(trxCap)/\/\/validateCommon(trxCap)/g" $WORKSPACE/java-tron/framework/src/main/java/org/tron/core/db/Manager.java

  sed -i 's/ApplicationFactory.create(context);/ApplicationFactory.create(context);saveNextMaintenanceTime(context);/g' $WORKSPACE/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  sed -i 's/shutdown(appT);/shutdown(appT);mockWitness(context);/g' $WORKSPACE/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  sed -i '$d' $WORKSPACE/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  sed -i "2a `cat $WORKSPACE/build_insert/FullNode_import | xargs`" $WORKSPACE/java-tron/framework/src/main/java/org/tron/program/FullNode.java
  cat $WORKSPACE/build_insert/FullNode_insert >> $WORKSPACE/java-tron/framework/src/main/java/org/tron/program/FullNode.java

  sed -i "s/private volatile boolean needSyncFromPeer = true/private volatile boolean needSyncFromPeer = false/g" $WORKSPACE/java-tron/framework/src/main/java/org/tron/core/net/peer/PeerConnection.java
  sed -i "s/private volatile boolean needSyncFromUs = true/private volatile boolean needSyncFromUs = false/g" $WORKSPACE/java-tron/framework/src/main/java/org/tron/core/net/peer/PeerConnection.java
  # build project
  ./gradlew clean build -x test -x check
}

# 指定配置文件
setVMOptions() {
  echo "info: package java-tron"
  rm -rf $WORKSPACE/java-tron-1.0.0/

  unzip -o -d $WORKSPACE $WORKSPACE/java-tron/build/distributions/java-tron-1.0.0.zip
  sed -i '$a-XX:+HeapDumpOnOutOfMemoryError' $WORKSPACE/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-XX:HeapDumpPath=/data/databackup/java-tron/heapdump/' $WORKSPACE/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote' $WORKSPACE/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote.port=9996' $WORKSPACE/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote.authenticate=false' $WORKSPACE/java-tron-1.0.0/bin/java-tron.vmoptions
  sed -i '$a-Dcom.sun.management.jmxremote.ssl=false' $WORKSPACE/java-tron-1.0.0/bin/java-tron.vmoptions

  echo "info: copy java-tron.vmoptions"
  #cp /data/workspace/replay_workspace/server_workspace/java-tron.vmoptions_cms /data/workspace/replay_workspace/server_workspace/java-tron-1.0.0/bin/java-tron.vmoptions
  # 10G内存配置
  cp $WORKSPACE/conf/duplicate/java-tron.vmoptions_cms $WORKSPACE/java-tron-1.0.0/bin/java-tron.vmoptions
}

sendWitnessNet() {
  cd $WORKSPACE
  echo "info: send witness node"
  for i in ${witnessNode[@]}; do
    ssh -p 22008 java-tron@$i 'cd /data/databackup/java-tron && rm -rf java-tron-1.0.0'
    tar -c java-tron-1.0.0/ |pigz |ssh -p 22008 java-tron@$i "gzip -d|tar -xC /data/databackup/java-tron/"
    scp -P 22008 $WORKSPACE/conf/config.conf_$i java-tron@$i:/data/databackup/java-tron/config.conf
    scp -P 22008 $WORKSPACE/stop_new.sh java-tron@$i:/data/databackup/java-tron/stop.sh
    scp -P 22008 $WORKSPACE/start_new_witness.sh java-tron@$i:/data/databackup/java-tron/start.sh
    echo "info: Send java-tron.jar and config.conf and start.sh to ${i} completed"
  done

  if [[ $useDatabaseBackup ]]; then
     for i in ${witnessNode[@]}; do
    echo "info: Delete database file of ${i} completed"
    ssh -p 22008 java-tron@$i 'rm -rf /data/databackup/java-tron/output-directory/'
    # 从目标机器本地复制，不是远程推送
    ssh -p 22008 java-tron@$i 'cp -r /data/databackup/java-tron/databaseBackup/output-directory/ /data/databackup/java-tron/'
    echo "info: Copy database file of ${i} completed"
  done
  wait
  else
    # 从中控机远程复制到目标机器

    echo 'info: Copy database from localhost'
  fi
}

sendFullNode() {
  cd $WORKSPACE/java-tron/
  for i in ${fullnodenet[@]}; do
    scp -P 22008 $WORKSPACE/start_new_fullnode.sh java-tron@$i:/data/databackup/java-tron/start.sh
  done

  for i in ${witnessNode[@]}; do
    ssh -p 22008 java-tron@$i 'source ~/.bash_profile && cd /data/databackup/java-tron && sh /data/databackup/java-tron/stop.sh'
    echo "info: Stop java-tron on ${i} completed"
  done
  backup_logname="`date +%Y%m%d%H%M%S`_backup.log"
  for i in ${witnessNode[@]}; do
    ssh -p 22008 java-tron@$i "mv /data/databackup/java-tron/logs/tron.log /data/databackup/java-tron/logs/$backup_logname"
    echo "info: Backup tron.log of ${i} complete"
  done


  for k in $(seq 10); do
  local currentminute=`date +%M | sed -r 's/^0+//'`
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

  for i in ${witnessNode[@]}; do
    ssh -p 22008 java-tron@$i 'source ~/.bash_profile && cd /data/databackup/java-tron && sh /data/databackup/java-tron/start.sh'
    ssh -p 22008 java-tron@$i 'find /data/databackup/java-tron/logs/ -mtime +10 -name "*" -exec rm -rf {} \;'
    echo "info: Start java-tron on ${i} completed"
  done
}

sendDuplicateNode() {
  for i in ${duplicateNodeIp[@]}; do
    # copy duplicate node config
    ssh -p 22008 java-tron@$i 'cd /data/databackup/java-tron-copy && sh /data/databackup/java-tron-copy/stop.sh'
    ssh -p 22008 java-tron@$i "rm -rf /data/databackup/java-tron-copy/output-directory/"
    echo "info: Delete duplicate node file of ${i} completed"
    # 从目标机器本地复制，不是远程推送
    echo "info: Copy duplicate node file of ${i} completed"
    scp -P 22008 $WORKSPACE/conf/duplicate/start_new_fullnode.sh java-tron@$i:/data/databackup/java-tron/start.sh
    scp -P 22008 $WORKSPACE/conf/duplicate/stop_new.sh java-tron@$i:/data/databackup/java-tron/stop.sh
    ssh -p 22008 java-tron@$i "cp /data/databackup/java-tron/stop.sh /data/databackup/java-tron-copy/"
    ssh -p 22008 java-tron@$i "cp -r /data/databackup/java-tron/java-tron-1.0.0/ /data/databackup/java-tron-copy/"

    echo "info: scp duplicate config file"
    scp -P 22008 $WORKSPACE/conf/duplicate/config.conf_$i java-tron@$i:/data/databackup/java-tron-copy/config.conf
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

#cloneCode
buildFullNode
setVMOptions
sendWitnessNet
sendFullNode

if [[ $DATABASE_BACKUP ]]; then

fi

# 使用备节点
if [ "$duplicateNode" = false ]; then
  sendDuplicateNode
fi
