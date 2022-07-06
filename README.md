# java-tron-stress 压测工具

模拟客户端对`java-tron`节点发起流量，模拟大流量交易场景。
主要是两个流程：
1. 构建和节点部署
2. 压测和结果收集

## 角色说明

* java-tron-stress: 压测工具
* FullNode：流量转发节点
* SR：打包节点

`java-tron-stress` 是发起交易的客户端
`FullNode` 相当于一个中心节点，负责接收`java-tron-stress`发送过来的流量，并易交易转发到SR节点
`SR` 消费`FullNode`转发过来的交易

## 构建和部署

需要部署两种节点类型：

* `FullNode`
* `SR`

节点数量根据实际需求配置，最少需要一个FullNode和一个SR。
构建预先内置测试账号，可直接用于压测的节点。需要对节点先进部分修改，比如添加内置账号，添加测试金额等。

### 构建FullNode

### 全量部署节点

编译、部署`FullNode`和`SR`节点，并从本地推送`数据库`，启动所有节点。

```shell script
sh deploy_with_liteDatabase.sh
```

java配置文件：
java-tron.vmoptions

## 压测命令

sh manual_send.sh 1000 /tmp/testAllTransaction/getTransactions.txt_10000_1212888 0 303222 3
