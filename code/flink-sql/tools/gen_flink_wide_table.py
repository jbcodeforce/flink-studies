#!/usr/bin/env python3
"""Generate Flink SQL DDL for a table with 5500 columns: STRING, DECIMAL, and one TIMESTAMP."""

OUTPUT_PATH = "flink_wide_table.sql"
TOTAL_COLUMNS = 5500
DECIMAL_INTERVAL = 55  # every Nth column (after ts) is DECIMAL -> ~100 decimal columns


def main() -> None:
    parts = [
        "CREATE TABLE wide_table (",
        "  ts TIMESTAMP(3),",
    ]
    # col_1 .. col_5499: mostly STRING, every DECIMAL_INTERVAL-th is DECIMAL(18,2)
    for i in range(1, TOTAL_COLUMNS):
        name = f"col_{i}"
        if i % DECIMAL_INTERVAL == 0:
            dtype = "DECIMAL(18, 2)"
        else:
            dtype = "STRING"
        parts.append(f"  {name} {dtype},")
    # remove trailing comma from last column
    parts[-1] = parts[-1].rstrip(",")
    parts.append(")")
    parts.append("WITH (")
    parts.append("  'connector' = 'datagen',")
    parts.append("  'number-of-rows' = '0'")
    parts.append(");")

    sql = "\n".join(parts)
    with open(OUTPUT_PATH, "w") as f:
        f.write(sql)
    print(f"Wrote {OUTPUT_PATH} ({TOTAL_COLUMNS} columns: 1 TIMESTAMP(3), ~{TOTAL_COLUMNS // DECIMAL_INTERVAL} DECIMAL(18,2), rest STRING)")


if __name__ == "__main__":
    main()
