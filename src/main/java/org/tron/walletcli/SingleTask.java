package org.tron.walletcli;

import org.tron.protos.Protocol.Transaction;
import org.tron.walletserver.GrpcClient;

public class SingleTask {

    private GrpcClient client;

    private Transaction transaction;

    public SingleTask(Transaction transaction, GrpcClient client) {
        this.transaction = transaction;
        this.client = client;
    }

    public GrpcClient getClient() {
        return client;
    }

    public void setClient(GrpcClient client) {
        this.client = client;
    }

    public Transaction getTransaction() {
        return transaction;
    }

    public void setTransaction(Transaction transaction) {
        this.transaction = transaction;
    }
}
