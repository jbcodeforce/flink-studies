package io.github.flinkstudies.perf.producer;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Standalone Kafka producer for Flink e2e performance testing.
 * Generates JSON records with configurable rate, message size, and duration.
 *
 * <p>Schema (JSON): id (long), event_time (ISO-8601), value (double), payload (string, for size).
 *
 * <p>Env: BOOTSTRAP_SERVERS (required). Args or env: topic, rate (msg/s), messageSizeBytes, durationSeconds, numThreads.
 */
public class DataGenerator {

    private static final String DEFAULT_TOPIC = "perf-input";
    private static final int DEFAULT_RATE_PER_SEC = 1_000;
    private static final int DEFAULT_MESSAGE_SIZE_BYTES = 256;
    private static final int DEFAULT_DURATION_SECONDS = 60;
    private static final int DEFAULT_NUM_THREADS = 1;

    public static void main(String[] args) throws InterruptedException {
        String bootstrap = System.getenv("BOOTSTRAP_SERVERS");
        if (bootstrap == null || bootstrap.isBlank()) {
            System.err.println("BOOTSTRAP_SERVERS environment variable is required");
            System.exit(1);
        }

        String topic = getOpt("topic", args, 0, "TOPIC", DEFAULT_TOPIC);
        int ratePerSec = Integer.parseInt(getOpt("rate", args, 1, "RATE_PER_SEC", String.valueOf(DEFAULT_RATE_PER_SEC)));
        int messageSizeBytes = Integer.parseInt(getOpt("messageSize", args, 2, "MESSAGE_SIZE_BYTES", String.valueOf(DEFAULT_MESSAGE_SIZE_BYTES)));
        int durationSeconds = Integer.parseInt(getOpt("duration", args, 3, "DURATION_SECONDS", String.valueOf(DEFAULT_DURATION_SECONDS)));
        int numThreads = Integer.parseInt(getOpt("threads", args, 4, "NUM_THREADS", String.valueOf(DEFAULT_NUM_THREADS)));

        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrap);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 16384);
        props.put(ProducerConfig.LINGER_MS_CONFIG, 5);
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, "none");

        AtomicLong globalId = new AtomicLong(0);
        int ratePerThread = ratePerSec / numThreads;
        if (ratePerThread < 1) ratePerThread = 1;
        final int ratePerThreadFinal = ratePerThread;
        final long deadline = System.currentTimeMillis() + durationSeconds * 1000L;
        final String topicFinal = topic;
        final Properties propsFinal = props;

        System.out.printf("Starting producer: topic=%s rate=%d msg/s size=%d bytes duration=%ds threads=%d%n",
                topic, ratePerSec, messageSizeBytes, durationSeconds, numThreads);

        ExecutorService executor = Executors.newFixedThreadPool(numThreads);

        for (int t = 0; t < numThreads; t++) {
            executor.submit(() -> {
                try (KafkaProducer<String, String> producer = new KafkaProducer<>(propsFinal)) {
                    long intervalNanos = 1_000_000_000L / ratePerThreadFinal;
                    long nextSend = System.nanoTime();
                    while (System.currentTimeMillis() < deadline) {
                        long id = globalId.incrementAndGet();
                        String value = buildRecord(id, messageSizeBytes);
                        producer.send(new ProducerRecord<>(topicFinal, String.valueOf(id), value));
                        nextSend += intervalNanos;
                        long now = System.nanoTime();
                        if (nextSend > now) {
                            long sleepNanos = nextSend - now;
                            TimeUnit.NANOSECONDS.sleep(sleepNanos);
                        }
                    }
                    producer.flush();
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            });
        }

        executor.shutdown();
        if (!executor.awaitTermination(durationSeconds + 30, TimeUnit.SECONDS)) {
            executor.shutdownNow();
        }

        long sent = globalId.get();
        System.out.printf("Sent %d records in %d seconds (%.0f msg/s)%n", sent, durationSeconds, (double) sent / durationSeconds);
    }

    private static String getOpt(String name, String[] args, int index, String envKey, String defaultValue) {
        if (args != null && index < args.length && args[index] != null && !args[index].isBlank()) {
            return args[index];
        }
        String env = System.getenv(envKey);
        return env != null && !env.isBlank() ? env : defaultValue;
    }

    static String buildRecord(long id, int targetSizeBytes) {
        String eventTime = Instant.now().toString();
        double value = Math.random();
        String base = String.format("{\"id\":%d,\"event_time\":\"%s\",\"value\":%.4f,\"payload\":\"", id, eventTime, value);
        String suffix = "\"}";
        int payloadLen = Math.max(0, targetSizeBytes - base.getBytes(StandardCharsets.UTF_8).length - suffix.getBytes(StandardCharsets.UTF_8).length);
        String payload = "x".repeat(payloadLen);
        return base + payload + suffix;
    }
}
