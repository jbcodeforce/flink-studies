package io.github.flinkstudies.perf.sqlexecutor;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SqlExecutorTest {

    @Test
    void parseStatements_splitsOnSemicolonOutsideParens() {
        String script = """
                CREATE TABLE a (x INT);
                -- comment
                INSERT INTO b SELECT * FROM a;
                """;
        List<String> stmts = SqlExecutor.parseStatements(script);
        assertEquals(2, stmts.size());
        assertTrue(stmts.get(0).toUpperCase().startsWith("CREATE TABLE"));
        assertTrue(stmts.get(1).toUpperCase().startsWith("INSERT"));
    }

    @Test
    void parseStatements_stripsBlockComments() {
        String script = "CREATE TABLE t (c INT) /* inline */; INSERT INTO t SELECT 1;";
        List<String> stmts = SqlExecutor.parseStatements(script);
        assertEquals(2, stmts.size());
        assertTrue(!stmts.get(0).contains("/*"));
    }
}
