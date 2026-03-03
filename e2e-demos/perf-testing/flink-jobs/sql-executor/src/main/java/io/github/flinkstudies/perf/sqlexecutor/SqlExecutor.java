package io.github.flinkstudies.perf.sqlexecutor;

import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Runs a SQL script against a Flink StreamTableEnvironment (Kafka source/sink).
 * Replaces placeholders ${BOOTSTRAP_SERVERS}, ${INPUT_TOPIC}, ${OUTPUT_TOPIC} from environment.
 */
public class SqlExecutor {

    private static final String STATEMENT_DELIMITER = ";";
    private static final Pattern COMMENT = Pattern.compile("(--.*)|(/\\*[\\w\\W]*?\\*/)");

    public static void main(String[] args) throws Exception {
        String bootstrap = System.getenv("BOOTSTRAP_SERVERS");
        if (bootstrap == null || bootstrap.isBlank()) {
            System.err.println("BOOTSTRAP_SERVERS environment variable is required");
            System.exit(1);
        }
        String inputTopic = System.getenv().getOrDefault("INPUT_TOPIC", "perf-input");
        String outputTopic = System.getenv().getOrDefault("OUTPUT_TOPIC", "perf-output");

        String script;
        if (args.length >= 1) {
            script = Files.readString(Path.of(args[0]));
        } else {
            try (var in = SqlExecutor.class.getResourceAsStream("/pipeline.sql")) {
                if (in == null) {
                    System.err.println("No script path given and /pipeline.sql not on classpath");
                    System.exit(1);
                }
                script = new String(in.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
            }
        }
        script = script
                .replace("${BOOTSTRAP_SERVERS}", bootstrap)
                .replace("${INPUT_TOPIC}", inputTopic)
                .replace("${OUTPUT_TOPIC}", outputTopic);

        List<String> statements = parseStatements(script);
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(
                env,
                EnvironmentSettings.newInstance().inStreamingMode().build()
        );

        TableResult lastResult = null;
        for (String stmt : statements) {
            String s = stmt.trim();
            if (s.isEmpty()) continue;
            System.out.println("Executing: " + s.substring(0, Math.min(80, s.length())) + "...");
            TableResult result = tableEnv.executeSql(s);
            if (s.toUpperCase().startsWith("INSERT")) {
                lastResult = result;
            }
        }
        if (lastResult != null) {
            lastResult.await();
        }
    }

    static List<String> parseStatements(String script) {
        String cleaned = COMMENT.matcher(script).replaceAll(" ").replaceAll("\\s+", " ").trim();
        if (!cleaned.endsWith(STATEMENT_DELIMITER)) {
            cleaned += STATEMENT_DELIMITER;
        }
        List<String> out = new ArrayList<>();
        int start = 0;
        int depth = 0;
        for (int i = 0; i < cleaned.length(); i++) {
            char c = cleaned.charAt(i);
            if (c == '(') depth++;
            else if (c == ')') depth--;
            else if (depth == 0 && c == ';') {
                String stmt = cleaned.substring(start, i).trim();
                if (!stmt.isEmpty()) out.add(stmt + ";");
                start = i + 1;
            }
        }
        return out;
    }
}
