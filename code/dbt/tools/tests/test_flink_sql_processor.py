"""Unit tests for flink_sql_processor.py."""

from __future__ import annotations

import pytest

from flink_dbt_migrate.flink_sql_processor import (
    DmlStatement,
    ValuesDmlStatement,
    clean_sql_literal,
    collect_cte_names,
    is_ctas,
    is_values_insert,
    parse_ctas,
    parse_ddl,
    parse_dml,
    parse_values_dml,
    strip_identifier,
    # private helpers exposed for direct testing
    _split_top_level,
    _split_top_level_tuples,
    _extract_balanced,
    _strip_sql_comments,
    _split_definitions,
)


# ===========================================================================
# strip_identifier
# ===========================================================================

class TestStripIdentifier:
    def test_backtick_wrapped(self):
        assert strip_identifier("`my_table`") == "my_table"

    def test_plain(self):
        assert strip_identifier("my_table") == "my_table"

    def test_strips_surrounding_whitespace(self):
        assert strip_identifier("  orders  ") == "orders"

    def test_backtick_with_spaces_inside(self):
        assert strip_identifier("`order items`") == "order items"


# ===========================================================================
# _split_top_level
# ===========================================================================

class TestSplitTopLevel:
    def test_simple_csv(self):
        assert _split_top_level("a, b, c") == ["a", " b", " c"]

    def test_nested_parens_not_split(self):
        result = _split_top_level("a, (b, c), d")
        assert len(result) == 3
        assert result[1] == " (b, c)"

    def test_string_literal_with_comma(self):
        result = _split_top_level("'hello, world', 42")
        assert len(result) == 2
        assert result[0] == "'hello, world'"

    def test_doubled_quote_escape_in_string(self):
        result = _split_top_level("'it''s', 2")
        assert len(result) == 2
        assert result[0] == "'it''s'"

    def test_empty_string(self):
        assert _split_top_level("") == [""]


# ===========================================================================
# _split_top_level_tuples
# ===========================================================================

class TestSplitTopLevelTuples:
    def test_single_tuple(self):
        assert _split_top_level_tuples("(1, 2, 3)") == ["1, 2, 3"]

    def test_multiple_tuples(self):
        result = _split_top_level_tuples("(1, 2), (3, 4)")
        assert result == ["1, 2", "3, 4"]

    def test_nested_tuple_kept_as_one(self):
        result = _split_top_level_tuples("((1, 2), 3)")
        assert result == ["(1, 2), 3"]

    def test_string_with_paren_inside(self):
        result = _split_top_level_tuples("('a(b)', 1)")
        assert result == ["'a(b)', 1"]

    def test_no_tuples(self):
        assert _split_top_level_tuples("no parens here") == []


# ===========================================================================
# _extract_balanced
# ===========================================================================

class TestExtractBalanced:
    def test_simple(self):
        text = "(hello)"
        content, end = _extract_balanced(text, 0)
        assert content == "hello"
        assert end == len(text)

    def test_nested(self):
        content, end = _extract_balanced("(a (b) c)", 0)
        assert content == "a (b) c"

    def test_not_opening_paren_raises(self):
        with pytest.raises(ValueError, match="Expected opening parenthesis"):
            _extract_balanced("hello", 0)

    def test_unbalanced_raises(self):
        with pytest.raises(ValueError, match="Unbalanced parentheses"):
            _extract_balanced("(unclosed", 0)

    def test_offset(self):
        text = "xx(inner)yy"
        content, end = _extract_balanced(text, 2)
        assert content == "inner"
        assert end == 9


# ===========================================================================
# _strip_sql_comments
# ===========================================================================

class TestStripSqlComments:
    def test_removes_inline_comment(self):
        assert _strip_sql_comments("SELECT 1 -- comment") == "SELECT 1 "

    def test_multiline(self):
        sql = "SELECT a -- col a\nFROM t -- table"
        result = _strip_sql_comments(sql)
        assert "--" not in result
        assert "SELECT a" in result
        assert "FROM t" in result

    def test_no_comment(self):
        assert _strip_sql_comments("SELECT 1") == "SELECT 1"


# ===========================================================================
# _split_definitions
# ===========================================================================

class TestSplitDefinitions:
    def test_simple_columns(self):
        body = "id BIGINT, name STRING, ts TIMESTAMP(3)"
        parts = _split_definitions(body)
        assert len(parts) == 3
        assert parts[0] == "id BIGINT"

    def test_nested_angle_brackets_not_split(self):
        body = "meta MAP<STRING, STRING>, val ARRAY<INT>"
        parts = _split_definitions(body)
        assert len(parts) == 2
        assert "MAP<STRING, STRING>" in parts[0]

    def test_skips_empty_pieces(self):
        parts = _split_definitions("  ,  a STRING  ,  ")
        assert all(p.strip() for p in parts)


# ===========================================================================
# clean_sql_literal
# ===========================================================================

class TestCleanSqlLiteral:
    def test_null(self):
        assert clean_sql_literal("NULL") is None
        assert clean_sql_literal("null") is None

    def test_string_literal(self):
        assert clean_sql_literal("'hello'") == "hello"

    def test_doubled_quote_unescaped(self):
        assert clean_sql_literal("'it''s'") == "it's"

    def test_date_literal(self):
        assert clean_sql_literal("DATE '2024-01-01'") == "2024-01-01"

    def test_timestamp_literal(self):
        assert clean_sql_literal("TIMESTAMP '2024-01-01 00:00:00'") == "2024-01-01 00:00:00"

    def test_time_literal(self):
        assert clean_sql_literal("TIME '12:00:00'") == "12:00:00"

    def test_numeric_passthrough(self):
        assert clean_sql_literal("42") == "42"

    def test_boolean_passthrough(self):
        assert clean_sql_literal("TRUE") == "TRUE"


# ===========================================================================
# is_values_insert
# ===========================================================================

class TestIsValuesInsert:
    def test_values_statement_returns_true(self):
        sql = "INSERT INTO t VALUES (1, 'a')"
        assert is_values_insert(sql) is True

    def test_select_statement_returns_false(self):
        sql = "INSERT INTO t SELECT id FROM src"
        assert is_values_insert(sql) is False

    def test_trailing_semicolon_handled(self):
        sql = "INSERT INTO t VALUES (1);"
        assert is_values_insert(sql) is True

    def test_no_insert_returns_false(self):
        assert is_values_insert("SELECT 1") is False

    def test_case_insensitive(self):
        assert is_values_insert("insert into t values (1)") is True


# ===========================================================================
# parse_values_dml
# ===========================================================================

class TestParseValuesDml:
    def test_basic(self):
        sql = "INSERT INTO orders (id, name) VALUES (1, 'alpha'), (2, 'beta')"
        result = parse_values_dml(sql, source_file="test.sql")
        assert isinstance(result, ValuesDmlStatement)
        assert result.target_table == "orders"
        assert result.columns == ["id", "name"]
        assert result.rows == [["1", "alpha"], ["2", "beta"]]
        assert result.source_file == "test.sql"

    def test_null_value(self):
        sql = "INSERT INTO t (a, b) VALUES (1, NULL)"
        result = parse_values_dml(sql)
        assert result.rows[0][1] is None

    def test_no_column_list(self):
        sql = "INSERT INTO t VALUES (1, 'x')"
        result = parse_values_dml(sql)
        assert result.columns == []
        assert result.rows == [["1", "x"]]

    def test_backtick_table(self):
        sql = "INSERT INTO `my_table` (id) VALUES (1)"
        result = parse_values_dml(sql)
        assert result.target_table == "my_table"

    def test_trailing_semicolon(self):
        sql = "INSERT INTO t (id) VALUES (99);"
        result = parse_values_dml(sql)
        assert result.rows == [["99"]]

    def test_mismatched_row_width_raises(self):
        sql = "INSERT INTO t (a, b) VALUES (1, 2), (3)"
        with pytest.raises(ValueError, match="Row has 1 values but 2 were expected"):
            parse_values_dml(sql)

    def test_no_rows_raises(self):
        sql = "INSERT INTO t (a) VALUES"
        with pytest.raises(ValueError):
            parse_values_dml(sql)

    def test_not_values_statement_raises(self):
        sql = "INSERT INTO t SELECT * FROM src"
        with pytest.raises(ValueError, match="Expected VALUES clause"):
            parse_values_dml(sql)


# ===========================================================================
# parse_dml
# ===========================================================================

class TestParseDml:
    def test_basic_select(self):
        sql = "INSERT INTO orders SELECT id, name FROM raw_orders"
        result = parse_dml(sql, source_file="dml.orders.sql")
        assert isinstance(result, DmlStatement)
        assert result.target_table == "orders"
        assert "SELECT id, name FROM raw_orders" in result.body
        assert result.source_file == "dml.orders.sql"

    def test_leading_comments_captured(self):
        sql = "-- my comment\nINSERT INTO t SELECT 1"
        result = parse_dml(sql)
        assert result.leading_comments == "-- my comment"

    def test_trailing_semicolon_stripped(self):
        sql = "INSERT INTO t SELECT 1;"
        result = parse_dml(sql)
        assert result.body == "SELECT 1"

    def test_values_raises(self):
        sql = "INSERT INTO t VALUES (1)"
        with pytest.raises(ValueError, match="INSERT INTO ... VALUES is not supported"):
            parse_dml(sql)

    def test_ctas_accepted(self):
        # parse_dml now routes CTAS statements through parse_ctas
        sql = "CREATE TABLE t AS SELECT 1"
        result = parse_dml(sql)
        assert result.target_table == "t"
        assert "SELECT 1" in result.body

    def test_no_insert_raises(self):
        with pytest.raises(ValueError, match="Expected INSERT INTO"):
            parse_dml("SELECT 1")

    def test_empty_body_raises(self):
        with pytest.raises(ValueError, match="empty SELECT body"):
            parse_dml("INSERT INTO t ")

    def test_backtick_table(self):
        sql = "INSERT INTO `fact_orders` SELECT id FROM src"
        result = parse_dml(sql)
        assert result.target_table == "fact_orders"


# ===========================================================================
# parse_ddl
# ===========================================================================

_SIMPLE_DDL = """
CREATE TABLE orders (
    id BIGINT NOT NULL,
    name STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'kafka',
    'topic' = 'orders'
);
"""

_DISTRIBUTED_DDL = """
CREATE TABLE events (
    event_id BIGINT NOT NULL,
    payload STRING
) DISTRIBUTED BY HASH (event_id)
WITH ('connector' = 'kafka', 'topic' = 'events');
"""

_IF_NOT_EXISTS_DDL = """
CREATE TABLE IF NOT EXISTS dim_users (
    user_id INT NOT NULL,
    email STRING
);
"""


class TestParseDdl:
    def test_table_name(self):
        table = parse_ddl(_SIMPLE_DDL)
        assert table.table_name == "orders"

    def test_columns(self):
        table = parse_ddl(_SIMPLE_DDL)
        assert len(table.columns) == 2
        col_names = [c.name for c in table.columns]
        assert "id" in col_names
        assert "name" in col_names

    def test_not_null(self):
        table = parse_ddl(_SIMPLE_DDL)
        id_col = next(c for c in table.columns if c.name == "id")
        assert id_col.not_null is True
        name_col = next(c for c in table.columns if c.name == "name")
        assert name_col.not_null is False

    def test_primary_key(self):
        table = parse_ddl(_SIMPLE_DDL)
        assert table.primary_key == ["id"]

    def test_with_options(self):
        table = parse_ddl(_SIMPLE_DDL)
        assert table.with_options["connector"] == "kafka"
        assert table.with_options["topic"] == "orders"

    def test_no_with_options(self):
        table = parse_ddl(_IF_NOT_EXISTS_DDL)
        assert table.with_options == {}

    def test_distributed_by(self):
        table = parse_ddl(_DISTRIBUTED_DDL)
        assert table.distributed_by == "event_id"

    def test_no_distributed_by(self):
        table = parse_ddl(_SIMPLE_DDL)
        assert table.distributed_by is None

    def test_if_not_exists(self):
        table = parse_ddl(_IF_NOT_EXISTS_DDL)
        assert table.table_name == "dim_users"

    def test_no_create_table_raises(self):
        with pytest.raises(ValueError, match="Expected CREATE TABLE"):
            parse_ddl("SELECT 1")

    def test_backtick_table_name(self):
        ddl = "CREATE TABLE `my_schema.orders` (id INT);"
        table = parse_ddl(ddl)
        assert table.table_name == "my_schema.orders"

    def test_complex_types(self):
        ddl = """
        CREATE TABLE complex_tbl (
            id INT,
            tags ARRAY<STRING>,
            meta MAP<STRING, STRING>
        );
        """
        table = parse_ddl(ddl)
        col_names = [c.name for c in table.columns]
        assert "tags" in col_names
        assert "meta" in col_names


    def test_lowercase_create_table(self):
        ddl = "create table orders (id BIGINT NOT NULL);"
        table = parse_ddl(ddl)
        assert table.table_name == "orders"



# ===========================================================================
# collect_cte_names
# ===========================================================================

class TestCollectCteNames:
    def test_single_cte(self):
        body = "WITH cte AS (SELECT 1) SELECT * FROM cte"
        assert collect_cte_names(body) == {"cte"}

    def test_multiple_ctes(self):
        body = "WITH a AS (SELECT 1), b AS (SELECT 2) SELECT * FROM a JOIN b ON TRUE"
        result = collect_cte_names(body)
        assert result == {"a", "b"}

    def test_no_cte(self):
        assert collect_cte_names("SELECT 1 FROM t") == set()

    def test_nested_cte_body_not_counted(self):
        # inner CTEs inside the body of a CTE should not be extracted
        body = "WITH outer_cte AS (WITH inner AS (SELECT 1) SELECT * FROM inner) SELECT * FROM outer_cte"
        result = collect_cte_names(body)
        assert "outer_cte" in result

    def test_backtick_cte_name(self):
        body = "WITH `my cte` AS (SELECT 1) SELECT * FROM `my cte`"
        result = collect_cte_names(body)
        assert "my cte" in result


# ===========================================================================
# is_ctas
# ===========================================================================

class TestIsCtas:
    def test_simple_ctas(self):
        assert is_ctas("CREATE TABLE t AS SELECT 1") is True

    def test_ctas_with_cte_body(self):
        sql = "CREATE TABLE order_volumes AS WITH cte AS (SELECT 1) SELECT * FROM cte"
        assert is_ctas(sql) is True

    def test_if_not_exists(self):
        assert is_ctas("CREATE TABLE IF NOT EXISTS t AS SELECT 1") is True

    def test_trailing_semicolon(self):
        assert is_ctas("CREATE TABLE t AS SELECT 1;") is True

    def test_insert_into_not_ctas(self):
        assert is_ctas("INSERT INTO t SELECT 1") is False

    def test_create_table_ddl_not_ctas(self):
        assert is_ctas("CREATE TABLE t (id INT)") is False

    def test_case_insensitive(self):
        assert is_ctas("create table t as select 1") is True
    
    def test_complex_ctas(self):
        sql ="""
        create table employee_count (
            dept_id INT NOT NULL,
            emp_count BIGINT NOT NULL,
            PRIMARY KEY(dept_id) NOT ENFORCED
        ) with (
        'changelog.mode' = 'upsert',
        'key.avro-registry.schema-context' = '.flink-dev',
        'value.avro-registry.schema-context' = '.flink-dev',
        'key.format' = 'avro-registry',
        'value.format' = 'avro-registry',
        'scan.bounded.mode' = 'unbounded',
        'kafka.cleanup-policy' = 'compact',
        'scan.startup.mode' = 'earliest-offset',
        'value.fields-include' = 'all'
        ) as 
        with deduplicated_employees as (
            select * from (
                select *,
                ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY emp_id DESC) as row_num
                from employees
            ) where row_num = 1
        )
        select coalesce(dept_id, 0) as dept_id, count(*) as emp_count from deduplicated_employees group by dept_id;
        """
        assert is_ctas(sql) is True


# ===========================================================================
# parse_ctas
# ===========================================================================

# Mirrors the real file at code/flink-sql/04-joins/cc-flink/cc-3-avg-prod-volume-per-mn.sql
_CTAS_WITH_CTE = """\
CREATE TABLE order_volumes AS
WITH orders_with_details AS (
  SELECT o.order_id, o.ts
  FROM d04_orders o
)
SELECT AVG(o.order_id) AS avg_vol, window_time
FROM orders_with_details o
GROUP BY window_time;
"""

_CTAS_PLAIN_SELECT = """\
CREATE TABLE employee_count AS
SELECT dept_id, COUNT(*) AS emp_count
FROM employees
GROUP BY dept_id;
"""

_CTAS_IF_NOT_EXISTS = """\
CREATE TABLE IF NOT EXISTS summary AS SELECT 1 AS val;
"""

_CTAS_WITH_OPTIONS = """\
CREATE TABLE result WITH (
    'connector' = 'kafka',
    'topic' = 'results'
) AS SELECT id, name FROM source_tbl;
"""

_CTAS_BACKTICK = """\
CREATE TABLE `fact.orders` AS SELECT id FROM raw;
"""

_CTAS_WITH_LEADING_PREAMBLE = """\
ALTER TABLE employee_count SET ('changelog-mode' = 'append');
CREATE TABLE employee_count AS
SELECT dept_id, COUNT(*) AS emp_count FROM employees GROUP BY dept_id;
"""

_CTAS_WITH_COLUMN_LIST = """\
create table employee_count (
    dept_id INT NOT NULL,
    emp_count BIGINT NOT NULL,
    PRIMARY KEY(dept_id) NOT ENFORCED
) with (
    'changelog.mode' = 'upsert',
    'key.format' = 'avro-registry',
    'value.format' = 'avro-registry'
) as
with deduplicated as (
    select * from employees
)
select dept_id, count(*) as emp_count from deduplicated group by dept_id;
"""


class TestParseCtas:
    def test_returns_ctas_statement(self):
        result = parse_ctas(_CTAS_PLAIN_SELECT, source_file="dml.sql")
        assert isinstance(result, DmlStatement)

    def test_target_table(self):
        assert parse_ctas(_CTAS_PLAIN_SELECT).target_table == "employee_count"

    def test_body_contains_select(self):
        result = parse_ctas(_CTAS_PLAIN_SELECT)
        assert result.body.upper().startswith("SELECT")

    def test_body_with_cte(self):
        result = parse_ctas(_CTAS_WITH_CTE)
        assert result.body.upper().startswith("WITH")
        assert "orders_with_details" in result.body

    def test_source_file_stored(self):
        result = parse_ctas(_CTAS_PLAIN_SELECT, source_file="mine.sql")
        assert result.source_file == "mine.sql"

    def test_trailing_semicolon_stripped_from_body(self):
        result = parse_ctas(_CTAS_PLAIN_SELECT)
        assert not result.body.rstrip().endswith(";")

    def test_if_not_exists(self):
        result = parse_ctas(_CTAS_IF_NOT_EXISTS)
        assert result.target_table == "summary"
        assert "SELECT 1" in result.body

    def test_backtick_table_name(self):
        result = parse_ctas(_CTAS_BACKTICK)
        assert result.target_table == "fact.orders"

    def test_with_options_parsed(self):
        result = parse_ctas(_CTAS_WITH_OPTIONS)
        assert result.target_table == "result"
        assert result.with_options["connector"] == "kafka"
        assert result.with_options["topic"] == "results"
        assert "SELECT id, name FROM source_tbl" in result.body

    def test_no_with_options_returns_empty_dict(self):
        result = parse_ctas(_CTAS_PLAIN_SELECT)
        assert result.with_options == {}

    def test_leading_preamble_captured(self):
        result = parse_ctas(_CTAS_WITH_LEADING_PREAMBLE)
        assert "ALTER TABLE" in result.leading_comments
        assert result.target_table == "employee_count"

    def test_no_leading_preamble_empty_string(self):
        result = parse_ctas(_CTAS_PLAIN_SELECT)
        assert result.leading_comments == ""

    def test_column_list_target_table(self):
        result = parse_ctas(_CTAS_WITH_COLUMN_LIST)
        assert result.target_table == "employee_count"

    def test_column_list_with_options_parsed(self):
        result = parse_ctas(_CTAS_WITH_COLUMN_LIST)
        assert result.with_options["changelog.mode"] == "upsert"
        assert result.with_options["key.format"] == "avro-registry"

    def test_column_list_body_starts_with_cte(self):
        result = parse_ctas(_CTAS_WITH_COLUMN_LIST)
        assert result.body.lower().startswith("with deduplicated")

    def test_not_a_ctas_raises(self):
        with pytest.raises(ValueError, match="Expected CREATE TABLE"):
            parse_ctas("INSERT INTO t SELECT 1")

    def test_missing_as_raises(self):
        with pytest.raises(ValueError, match="Expected CREATE TABLE"):
            parse_ctas("CREATE TABLE t (id INT)")

    def test_empty_body_raises(self):
        with pytest.raises(ValueError, match="empty SELECT body"):
            parse_ctas("CREATE TABLE t AS")


class TestParseDmlCtasGuard:
    """parse_dml routes CTAS statements through parse_ctas transparently."""

    def test_ctas_plain_select_accepted(self):
        result = parse_dml("CREATE TABLE t AS SELECT 1")
        assert result.target_table == "t"
        assert "SELECT 1" in result.body

    def test_ctas_with_cte_accepted(self):
        result = parse_dml("CREATE TABLE t AS WITH cte AS (SELECT 1) SELECT * FROM cte")
        assert result.target_table == "t"
        assert result.body.upper().startswith("WITH")
