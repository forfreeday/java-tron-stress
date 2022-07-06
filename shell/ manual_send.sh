#!/bin/bash

# 使用命令
# 1000 TPS
# getTransactions.txt_10000_1212888  交易
# 0 交易开始笔数 303222 交易结束笔数
# sh manual_send.sh 1000 /tmp/testAllTransaction/getTransactions.txt_10000_1212888 0 303222 6

repository="https://github.com/forfreeday/java-tron-stress.git"
local_stress_project="$PWD/java-tron-stress"
branch_name=main

default_qps=100
default_filePath=""
VM_OPTIONS=""

result_resrver="http://10.40.100.110:50090/"
result_interface="wallet/getnowblock"

replayServer=10.40.100.110:50090
echo "info: QPS" $qps

# 生成报告时，查询被压测的witness节点，必须和config.conf中配置的相同
testWitness=(
10.40.100.110
10.40.100.111
10.40.100.114
10.40.100.115
10.40.100.116
)

#testnet=(
#10.40.100.110
#10.40.100.111
#10.40.100.114
#10.40.100.115
#10.40.100.116
#10.40.100.117
#)

if [ ! -d $local_stress_project ]; then
  git clone $repository
  cd $local_stress_project
  git checkout $branch_name
  ./gradlew build -x test
else
  cd $local_stress_project
 # git reset --hard origin/$branch_name
  git pull
  git checkout $branch_name
  ./gradlew build -x test
fi

if [ -n "$1" ]; then
  VM_OPTIONS="$VM_OPTIONS -Dqps=$1 "
else
  VM_OPTIONS="$VM_OPTIONS -Dqps=$default_qps "
fi

if [ -n "$2" ]; then
  VM_OPTIONS="$VM_OPTIONS -DfilePath=$2 "
fi

if [ -n "$3" ]; then
  VM_OPTIONS="$VM_OPTIONS -DstartBlock=$3 "
fi

if [ -n "$4" ]; then
  VM_OPTIONS="$VM_OPTIONS -DendBlock=$4 "
fi

if [ -n "$5" ]; then
  VM_OPTIONS="$VM_OPTIONS -DfullNode=$5 "
fi

runJavaTronStress() {
  export replayStartNum=`curl -s -X POST $result_resrver$result_interface | jq .block_header.raw_data.number`
  export replayStartNum=$[$replayStartNum + 10]
  echo "info: replayStartNum: " $replayStartNum

  java -jar $VM_OPTIONS $local_stress_project/build/libs/wallet-cli.jar

  export replayEndNum=`curl -s -X POST  http://10.40.100.110:50090/wallet/getnowblock | jq .block_header.raw_data.number`
  export replayEndNum=$[$replayEndNum - 10]

  echo "info: end the program"
}

statisticsResult() {
  replayStartTime=`curl -s -X POST http://$replayServer/wallet/getblockbynum -d \{"num":$replayStartNum}\ | jq .block_header.raw_data.timestamp`
  replayEndTime=`curl -s -X POST http://$replayServer/wallet/getblockbynum -d \{"num":$replayEndNum}\ | jq .block_header.raw_data.timestamp`
  echo "replayStartNum: $replayStartNum"
  echo "replayEndNum: $replayEndNum"
  TransactionCount=1
  for((i=replayStartNum;i<=replayEndNum;i++));
    do
    # 计算所有区块中包含的交易笔数
    transactionNumInThisBlock=`curl -s -X POST http://$replayServer/wallet/getblockbynum -d \{"num":$i}\ | jq . | grep "txID" | wc -l`
    TransactionCount=$[$TransactionCount+$transactionNumInThisBlock]
  done

  blockInterval=$((replayEndNum - replayStartNum))
  # 算出处理一个区块的平均时间
  targetTime=`expr $blockInterval \* 3`
  echo "info: block interval is: " $blockInterval
  echo "info: targetTime is: " $targetTime

  # 开始到结束的时间差: ms
  totalCostTime=$((replayEndTime - replayStartTime))
  # 换算成: 秒
  costTime=$(($totalCostTime/1000))
  # tps = 总交易笔数 / 总耗时
  tps=$(($TransactionCount/$costTime))
  costHours=$(printf "%.2f" `echo "scale=2;$costTime/3600"|bc`)
  backwardTime=$(($costTime-$targetTime))
  MissBlockRate=`awk 'BEGIN{printf "%.1f%\n",('$backwardTime'/'$costTime')*100}'`
  echo "info: Total transactions: $TransactionCount, cost time: $costHours"h", average tps: $tps/s, MissBlockRate: $MissBlockRate"
  replay_massage="info: 1.Replay report: Total transactions: $TransactionCount, cost time: $costHours"h", average tps: $tps/s, MissBlockRate: $MissBlockRate"

}

report() {
  export currentBlockNumber=`curl -s -X POST  http://10.40.100.110:50090/wallet/getnowblock | jq .block_header.raw_data.number`

  export witness_produce_block_status=`sh /data/workspace/replay_workspace/query_witness_status.sh`
  echo "--------------hello-------------"
  cur_data=`date +%Y-%m-%d`
  report_text="`date +%Y-%m-%d` 现网流量回放报告："
  #########echo "Replay Main Net flow report:" >> /data/workspace/replay_workspace/Replay_Daily_Report
  echo $replay_massage >> /data/workspace/replay_workspace/Replay_Daily_Report
  echo $witness_produce_block_status >> /data/workspace/replay_workspace/Replay_Daily_Report
  echo "--------------hello-------------"
  #echo $witness_produce_block_status_liqi >> /data/workspace/replay_workspace/Replay_Daily_Report

  report_text=$report_text"\n"$replay_massage
  report_text=$report_text"\n"$witness_produce_block_status
  for i in ${testWitness[@]}; do
    export node_ip=$i
    get_CPU_MEM_result=""
    replay_log=`ssh -p 22008 java-tron@$i "grep 'at org.tron' /data/databackup/java-tron/logs/tron.log"`
    gc_log=`ssh -p 22008 java-tron@$i "grep 'Full GC' /data/databackup/java-tron/gc.log"`
    if [ -z "$replay_log" ]; then
      report_text="$report_text\n$i has no Exception. $get_CPU_MEM_result"
      echo "$i has no Exception. $get_CPU_MEM_result" >> /data/workspace/replay_workspace/Stress_Daily_Report
    else
      echo "$replay_log. $get_CPU_MEM_result" >> /data/workspace/replay_workspace/Stress_Daily_Report
      report_text="$i $report_text\n$replay_log. $get_CPU_MEM_result"
    fi

    if [ -z "$gc_log" ]; then
      report_text="$report_text\n$i has no Full GC. $get_CPU_MEM_result"
      echo "$i has no Full GC. $get_CPU_MEM_result" >> /data/workspace/replay_workspace/Stress_Daily_Report
    else
      echo "$replay_log. $get_CPU_MEM_result" >> /data/workspace/replay_workspace/Stress_Daily_Report
      report_text="$i $report_text\n$i has Full GC,please check. $get_CPU_MEM_result"
    fi

  done
  #echo $report_text
  #`slack $report_text`
  #curl "https://oapi.dingtalk.com/robot/send?access_token=78304ebbbd027113ac62080541818c0fe12fd8d66b29e1b598b5f0594eda0f92" \
  #    -H 'Content-Type: application/json' \
  #    -d "
  #{
  #    \"msgtype\": \"text\",
  #    \"text\": {
  #        \"content\": \"$report_text\"
  #    }
  #}
  #"
}

runJavaTronStress

statisticsResult

report
