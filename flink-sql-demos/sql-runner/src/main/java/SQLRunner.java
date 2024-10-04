

import org.apache.flink.util.FileUtils;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.table.api.TableEnvironment;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


/**
 * count the number of time a name appears in a list
 */
public class SQLRunner {


    private static final String STATEMENT_DELIMITER = ";"; // a statement should end with `;`
    private static final String LINE_DELIMITER = "\n";

    private static final String COMMENT_PATTERN = "(--.*)|(((\\/\\*)+?[\\w\\W]+?(\\*\\/)+))";

    private static final Pattern SET_STATEMENT_PATTERN =
            Pattern.compile("SET\\s+'(\\S+)'\\s+=\\s+'(.*)';", Pattern.CASE_INSENSITIVE);

    private static final String BEGIN_CERTIFICATE = "-----BEGIN CERTIFICATE-----";
    private static final String END_CERTIFICATE = "-----END CERTIFICATE-----";
    private static final String ESCAPED_BEGIN_CERTIFICATE = "======BEGIN CERTIFICATE=====";
    private static final String ESCAPED_END_CERTIFICATE = "=====END CERTIFICATE=====";


    
 public static void main(String[] args) throws Exception {
    if (args.length != 1) {
        throw new Exception("Need to get the file of the SQL file to interpret.");
    }
    script = FileUtils.readFileUtf8(new File(args[0]));
    statements = parseStatements(script);

    tableEnv = TableEnvironment.create(new Configuration());

    for (String statement : statements) {
        Matcher setMatcher = SET_STATEMENT_PATTERN.matcher(statement.trim());

        if (setMatcher.matches()) {
            // Handle SET statements
            String key = setMatcher.group(1);
            String value = setMatcher.group(2);
            tableEnv.getConfig().getConfiguration().setString(key, value);
        } else {
            tableEnv.executeSql(statement);
        }
    }
 }   
}
