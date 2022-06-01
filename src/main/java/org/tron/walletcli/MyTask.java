package org.tron.walletcli;

import org.tron.protos.Protocol;
import org.tron.protos.Protocol.Transaction;
import org.tron.walletserver.GrpcClient;

import java.util.List;

public class MyTask implements Runnable {

  private Transaction trans;
  private GrpcClient client;

  List<SingleTask> taskList;

  public MyTask(List<SingleTask> taskList) {
    this.taskList = taskList;
  }

  public MyTask(Transaction trans, GrpcClient client) {
    this.trans = trans;
    this.client = client;
  }

  @Override
  public void run() {
    if (null == taskList) {
      client.broadcastTransaction(trans);
    } else {
      taskList.parallelStream().forEach(singleTask -> {
        GrpcClient client = singleTask.getClient();
        Protocol.Transaction transaction = singleTask.getTransaction();
        client.broadcastTransaction(transaction);
      });
    }
  }

}
