#!/bin/bash
WORK_DIR=/data/databackup/java-tron-develop
NODE_SEQ=node1

# sh build.sh node1
# sh build.sh node2
if [ -n "$1" ] ;then
  NODE_SEQ=$1
fi

mkdir -p $WORK_DIR/source
cd $WORK_DIR/source
git clone https://github.com/tronprotocol/java-tron.git
cd java-tron/
./gradlew clean build -x test
cp build/libs/FullNode.jar $WORK_DIR
cp start.sh $WORK_DIR
cd $WORK_DIR
wget https://raw.githubusercontent.com/forfreeday/java-tron-stress/main/shell/config/sr-develop/$NODE_SEQ/config.conf
