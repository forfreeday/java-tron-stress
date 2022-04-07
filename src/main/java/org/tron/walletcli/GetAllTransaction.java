package org.tron.walletcli;

import com.google.protobuf.InvalidProtocolBufferException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.spongycastle.util.encoders.Hex;
import org.tron.api.GrpcAPI.BlockList;
import org.tron.api.GrpcAPI.ExchangeList;
import org.tron.protos.Protocol.Block;
import org.tron.protos.Protocol.Transaction;
import org.tron.protos.Protocol.Transaction.Contract.ContractType;
import org.tron.walletserver.GrpcClient;
import org.tron.walletserver.WalletApi;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import java.util.function.Predicate;
import java.util.stream.Collectors;

public class GetAllTransaction {

    public static List<Transaction> transactions = new ArrayList<>();
    private static String TRANSACTION_FILE_PATH = "getTransactions.txt";
    private static int QPS = 0;
    private static int DEFAULT_QPS = 100;
    private static Logger LOGGER = LoggerFactory.getLogger(GetAllTransaction.class);

    private static final int CORE_SIZE = Runtime.getRuntime().availableProcessors();
    private static final int MAX_SIZE = CORE_SIZE + 1;
    private static final int KEEP_ALIVE_TIME = 10000;

    public static Transaction HexStringToTransaction(String HexString) {
        Transaction signedTransaction = null;
        try {
            signedTransaction = Transaction.parseFrom(Hex.decode(HexString));
        } catch (InvalidProtocolBufferException ignore) {
            System.out.println(HexString);
        }
        return signedTransaction;
    }

    public static String TransactionToHexString(Transaction trx) {
        return Hex.toHexString(trx.toByteArray());
    }

//    public static void fetchTransaction(GrpcClient client, String filename, int startBlockNum,
//                                        int endBlockNum) {
//        int step = 100;
//        Optional<ExchangeList> eList = client.listExchanges();
//        System.out.println(String.format("提取从%s块～～%s块的交易!", startBlockNum, endBlockNum));
//        for (int i = startBlockNum; i < endBlockNum; i = i + step) {
//            Optional<BlockList> result = client.getBlockByLimitNext(i, i + step);
//            if (result.isPresent()) {
//                BlockList blockList = result.get();
//                if (blockList.getBlockCount() > 0) {
//                    for (Block block : blockList.getBlockList()) {
//                        if (block.getTransactionsCount() > 0) {
//                            transactions.addAll(block.getTransactionsList());
//                        }
//                    }
//                }
//            }
//            LOGGER.info(String.format("已提取%s块～～%s块的交易!", i, i + step));
//        }
//
//        System.out.println("总交易数量：" + transactions.size());
//        transactions = transactions.stream().filter(new Predicate<Transaction>() {
//            @Override
//            public boolean test(Transaction transaction) {
//                ContractType type = transaction.getRawData().getContract(0).getType();
//                return type == ContractType.TransferContract
//                        || type == ContractType.TransferAssetContract
//                        || type == ContractType.AccountCreateContract
//                        || type == ContractType.VoteAssetContract
//                        || type == ContractType.AssetIssueContract
//                        || type == ContractType.ParticipateAssetIssueContract
//                        || type == ContractType.FreezeBalanceContract
//                        || type == ContractType.UnfreezeBalanceContract
//                        || type == ContractType.UnfreezeAssetContract
//                        || type == ContractType.UpdateAssetContract
//                        || type == ContractType.ProposalCreateContract
//                        || type == ContractType.ProposalApproveContract
//                        || type == ContractType.ProposalDeleteContract
//                        || type == ContractType.SetAccountIdContract
//                        || type == ContractType.CustomContract
//                        || type == ContractType.CreateSmartContract
//                        || type == ContractType.TriggerSmartContract
//                        || type == ContractType.ExchangeCreateContract
//                        || type == ContractType.UpdateSettingContract
//                        || type == ContractType.ExchangeInjectContract
//                        || type == ContractType.ExchangeWithdrawContract
//                        || type == ContractType.ExchangeTransactionContract
//                        || type == ContractType.UpdateEnergyLimitContract
//                        ;
//            }
//        }).collect(Collectors.toList());
//        LOGGER.info("满足交易数量：" + transactions.size());
//
//        try {
//            long t2 = System.currentTimeMillis();
//            LOGGER.info("开始向文件写入交易数据，请稍后...");
//            FileWriter fw = new FileWriter(filename, true); //the true will append the new data
//
//            OutputStreamWriter write = new OutputStreamWriter(new FileOutputStream(new File(filename)));
//            BufferedWriter writer = new BufferedWriter(write);
//
//            transactions.parallelStream().forEachOrdered(new Consumer<Transaction>() {
//                @Override
//                public void accept(Transaction trx) {
//                    try {
//                        writer.write(TransactionToHexString(trx) + System.lineSeparator());
//                    } catch (IOException e) {
//                        e.printStackTrace();
//                    }
//                }
//            });
//            writer.flush();
//            write.close();
//            writer.close();
//
//            LOGGER.info("交易数据写入完成，文件名称：" + filename);
//            LOGGER.info("写入文件花费" + (System.currentTimeMillis() - t2) + "ms");
//        } catch (IOException ioe) {
//            System.err.println("IOException: " + ioe.getMessage());
//        }
//
//    }

    public static void sendTransaction(List<GrpcClient> clients, String filename, int qps) throws InterruptedException {
        List<Transaction> transactionList = new ArrayList<>();
        ThreadPoolExecutor executor = new ThreadPoolExecutor(
                CORE_SIZE,
                MAX_SIZE,
                KEEP_ALIVE_TIME,
                TimeUnit.MILLISECONDS,
                new LinkedBlockingQueue<>());
        try {
            getTransaction(filename, transactionList);
        } catch (IOException e) {
            e.printStackTrace();
        }

        LOGGER.info("Start send time is " + System.currentTimeMillis());
        // 线程池发送
        for (int i = 0; i < transactionList.size(); i = i + qps ) {

            long startTimestamp = System.currentTimeMillis();
            for (int j = i; j < i + qps && j < transactionList.size(); j++) {
                executor.execute(new MyTask(transactionList.get(j), clients.get(j % clients.size())));
            }
            long costTime = System.currentTimeMillis() - startTimestamp;
            if (costTime < 980) {
                Thread.sleep(980 - costTime);
            } else {
                LOGGER.info("qps set error!");
            }
        }
        LOGGER.info("End send time is " + System.currentTimeMillis());

        int i = 0;
        long progressTaskNum = -1L;
        while (i++ < 3600) {
            Thread.sleep(10000);
            if (progressTaskNum == executor.getCompletedTaskCount()) {
                System.exit(1);
            }
            progressTaskNum = executor.getCompletedTaskCount();
            LOGGER.info(String.valueOf(executor.getCompletedTaskCount()));
        }

    }

    private static void getTransaction(String filename, List<Transaction> transactionList) throws IOException {
        InputStreamReader read = new InputStreamReader(new FileInputStream(new File(filename)));
        BufferedReader reader = new BufferedReader(read);
        String trx = reader.readLine();
        while (trx != null) {
            transactionList.add(HexStringToTransaction(trx));
            trx = reader.readLine();
        }
    }

    public static void sendTransaction(List<GrpcClient> clients, String filename) {

        List<Transaction> transactionList = new ArrayList<>();
        ThreadPoolExecutor executor = new ThreadPoolExecutor(20, 20, 200, TimeUnit.MILLISECONDS,
                new LinkedBlockingQueue<Runnable>());
        //ThreadPoolExecutor executor = (ThreadPoolExecutor) Executors.newCachedThreadPool();
        try {
            FileReader fr = new FileReader(filename);
            getTransaction(filename, transactionList);
        } catch (IOException e) {
            e.printStackTrace();
        }

        LOGGER.info("Start send time is " + System.currentTimeMillis());
        // 线程池发送
        for (int i = 0; i < transactionList.size(); i++) {
            executor.execute(new MyTask(transactionList.get(i), clients.get(i % clients.size())));
        }
        LOGGER.info("End send time is " + System.currentTimeMillis());

        int i = 0;
        long progressTaskNum = -1L;
        while (i++ < 3600) {
            try {
                Thread.sleep(10000);
            } catch (InterruptedException ignored) {
            }
            if (progressTaskNum == executor.getCompletedTaskCount()) {
                System.exit(1);
            }
            progressTaskNum = executor.getCompletedTaskCount();
            LOGGER.info(String.valueOf(executor.getCompletedTaskCount()));
        }
    }

    public static void main(String[] args) throws InterruptedException {

        if (args != null && args.length > 0) {
            QPS = Integer.parseInt(args[0]);
        } else {
            QPS = DEFAULT_QPS;
        }

        List<GrpcClient> clients = new ArrayList<>();
        //对应 config.conf 的 fullnode.ip.list
        GrpcClient client0 = WalletApi.init(0);
        clients.add(client0);
        sendTransaction(clients, TRANSACTION_FILE_PATH, QPS);
        //将历史交易重放到测试环境下，测试节点取消交易验证和Tapos验证
    }
}
