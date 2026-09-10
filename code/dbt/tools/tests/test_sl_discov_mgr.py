from dataclasses import asdict
import json
from pathlib import Path
from typing import List

from flink_dbt_migrate.sl_discovery_mgr import (
    _upstream_ddl_map_from_pipeline_def,
    _find_pipelines_parent,
    TableEntry,
    crawl_pipeline_folder
)

dbt_mig_path =  Path(__file__).resolve().parent # flink_dbt_migrate
sl_test_pipeline_path = dbt_mig_path.parents[4] / "shift_left_utils" / "src" / "shift_left" / "tests" / "data" / "flink-project" / "pipelines"


def  test__find_pipelines_parent() :
    print(sl_test_pipeline_path)
    pipeline_parent = _find_pipelines_parent(sl_test_pipeline_path)
    assert "pipelines" not in str(pipeline_parent)
   

def test__upstream_ddl_map_from_pipeline_def() :
    print(sl_test_pipeline_path)
    pipeline_parent = _find_pipelines_parent(sl_test_pipeline_path)
    table_dir  = sl_test_pipeline_path / "dimensions" / "c360" / "dim_groups"
    upstream_ddl_map = _upstream_ddl_map_from_pipeline_def(table_dir, pipeline_parent)
    assert len(upstream_ddl_map) == 2
    assert "src_tenant" in str(upstream_ddl_map['sl_cmn_src_tenants'])


def test_crawl_pipeline_folder() :
    table_entries: List[TableEntry] = crawl_pipeline_folder(sl_test_pipeline_path)
    assert table_entries
    assert len(table_entries) > 0
    print(json.dumps([asdict(e) for e in table_entries], indent=2, default=str))
    

    