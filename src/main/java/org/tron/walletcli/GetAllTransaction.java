package org.tron.walletcli;

import com.google.protobuf.InvalidProtocolBufferException;
import com.typesafe.config.Config;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.spongycastle.util.encoders.Hex;
import org.tron.core.config.Configuration;
import org.tron.protos.Protocol.Transaction;
import org.tron.walletserver.GrpcClient;
import org.tron.walletserver.WalletApi;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

// java -Dqps=10000 -DfilePath=getTransactions.txt_10000_1212888 -DstartBlock=100 -DendBlock=299999 -DfullNode=0 -jar java-tron-strees
public class GetAllTransaction {

    public static List<Transaction> transactions = new ArrayList<>();
    private static String TRANSACTION_FILE_PATH = "getTransactions.txt";
    private static int DEFAULT_QPS = 100;
    private static final Logger LOGGER = LoggerFactory.getLogger(GetAllTransaction.class);

    private static final int CORE_SIZE = Runtime.getRuntime().availableProcessors();
    private static final int MAX_SIZE = CORE_SIZE * 10 + 1;
    private static final int KEEP_ALIVE_TIME = 300;

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


    public static List<Transaction> getTransactions(String filename, int start, int end) {
        List<Transaction> transactionList = new ArrayList<>();
        try {
            InputStreamReader read = new InputStreamReader(new FileInputStream(new File(filename)));
            BufferedReader reader = new BufferedReader(read);
            String trx = reader.readLine();
            if (end > 0) {
                int count = 0;
                while (trx != null) {
                    if (count > start && count <= end) {
                        transactionList.add(HexStringToTransaction(trx));
                    }
                    trx = reader.readLine();
                    count++;
                }
            } else {
                while (trx != null) {
                    transactionList.add(HexStringToTransaction(trx));
                    trx = reader.readLine();
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return transactionList;
    }


    public static void sendTransaction(List<GrpcClient> clients, String filename, int qps, Integer start, Integer end) throws InterruptedException {
        List<Transaction> transactionList = null;
        try {
            if (start != null && end != null) {
                transactionList = getTransactions(filename, start, end);
            } else {
                transactionList = getTransaction(filename);
            }
        } catch (IOException e) {
            LOGGER.warn("get transactions error: {}", e.getMessage(), e);
        }

        ThreadPoolExecutor executor = new ThreadPoolExecutor(
                CORE_SIZE,
                MAX_SIZE,
                KEEP_ALIVE_TIME,
                TimeUnit.MILLISECONDS,
                new LinkedBlockingQueue<>());

        LOGGER.info("Start send time is: " + System.currentTimeMillis());
        // 线程池发送
        for (int i = 0; i < transactionList.size(); i = i + qps) {
            long startTimestamp = System.currentTimeMillis();
            for (int j = i; j < i + qps && j < transactionList.size(); j++) {
                executor.execute(new MyTask(transactionList.get(j), clients.get(j % clients.size())));
            }
            long costTime = System.currentTimeMillis() - startTimestamp;
            if (costTime < 980) {
                Thread.sleep(980 - costTime);
            } else {
                LOGGER.warn("qps set error!");
            }
        }
        LOGGER.info("End send time is: " + System.currentTimeMillis());

        int i = 0;
        long progressTaskNum = -1L;
        while (i++ < 3600) {
            Thread.sleep(10000);
            if (progressTaskNum == executor.getCompletedTaskCount()) {
                System.exit(1);
            }
            progressTaskNum = executor.getCompletedTaskCount();
            LOGGER.info("Completed task count: {}" ,executor.getCompletedTaskCount());
        }

    }

    private static List<Transaction> getTransaction(String filename) throws IOException {
        List<Transaction> transactionList = new ArrayList<>();
        InputStreamReader read = new InputStreamReader(new FileInputStream(new File(filename)));
        BufferedReader reader = new BufferedReader(read);
        String trx = reader.readLine();
        while (trx != null) {
            transactionList.add(HexStringToTransaction(trx));
            trx = reader.readLine();
        }
        return transactionList;
    }

    public static void sendTransaction(List<GrpcClient> clients, String filename) {

        List<Transaction> transactionList = null;
        ThreadPoolExecutor executor = new ThreadPoolExecutor(20, 20, 200, TimeUnit.MILLISECONDS,
                new LinkedBlockingQueue<>());
        try {
            transactionList = getTransaction(filename);
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

    /**
     * GrpcClient 对应 config.conf 的 fullnode.ip.list
     *  多个 FullNode 就添加多个 fullnode.ip.list，通过 GrpcClient 进行初始化
     * @throws InterruptedException interrupted
     */
    public static void main(String[] args) throws InterruptedException {
        int qps;
        String qpsParam = System.getProperty("qps");
        if (StringUtils.isNoneEmpty(qpsParam)) {
            qps = Integer.parseInt(qpsParam);
        } else {
            qps = DEFAULT_QPS;
        }

        String filePath = System.getProperty("filePath");

        if (StringUtils.isEmpty(filePath)) {
            filePath = TRANSACTION_FILE_PATH;
        }

        LOGGER.info("init filePath: {}", filePath);
        String startParam = System.getProperty("start");
        Integer start = null;
        if (StringUtils.isNoneEmpty(startParam)) {
            start = Integer.parseInt(startParam);
        }

        String endParam = System.getProperty("end");
        Integer end = null;
        if (StringUtils.isNoneEmpty(endParam)) {
            end = Integer.parseInt(endParam);
        }

        LOGGER.info("init param: qps: {}, filePath: {}, start: {}, end: {}", qps, filePath, start, end);
        List<GrpcClient> clients = new ArrayList<>();
        String fullNode = System.getProperty("fullNode");
        if (StringUtils.isNoneEmpty(fullNode)) {
            int i = Integer.parseInt(fullNode);
            GrpcClient client = WalletApi.init(i);
            clients.add(client);
        } else {
            Config config = Configuration.getByPath("config.conf");
            List<String> fullNodes = config.getStringList("fullnode.ip.list");
            for (int i = 0; i < fullNodes.size(); i++) {
                GrpcClient client = WalletApi.init(i);
                clients.add(client);
            }
        }
        //将历史交易重放到测试环境下，测试节点取消交易验证和Tapos验证
        sendTransaction(clients, filePath, qps, start, end);
    }
}
