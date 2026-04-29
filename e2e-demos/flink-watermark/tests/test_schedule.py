"""Unit tests for schedule helpers (TDD for producer counts)."""

from datetime import datetime, timezone

import pytest

from flink_watermark.schedule import (
    ProducerPlan,
    default_plan,
    event_time_at_offset,
    events_for_target_window_included,
    format_event_time_iso,
)


def test_event_time_at_offset_rejects_naive_base() -> None:
    naive = datetime(2020, 1, 1, 0, 0, 0)
    with pytest.raises(ValueError, match="timezone-aware"):
        event_time_at_offset(naive, 0)


def test_format_event_time_iso_utc_z() -> None:
    ts = datetime(2020, 1, 1, 0, 0, 50, 123000, tzinfo=timezone.utc)
    s = format_event_time_iso(ts)
    assert s == "2020-01-01T00:00:50.123Z"



def test_default_plan_counts() -> None:
    pl = default_plan()
    # Phase1: 21 seconds * 4 partitions
    assert pl.phase1_events == 84
    # Phase2: (59 - 21 + 1) * 2 = 39 * 2 = 78
    assert pl.phase2_events == 78
    assert pl.phase1_events + pl.phase2_events == 162


def test_target_window_event_count() -> None:
    pl = default_plan()
    # [50, 60): t = 50..59 on p0 and p1 only in phase2
    n = events_for_target_window_included(pl, 50, 60)
    assert n == 20


def test_smoke_custom_plan() -> None:
    pl = ProducerPlan(
        phase1_end_inclusive_sec=0,
        phase2_start_sec=1,
        phase2_end_inclusive_sec=0,
        num_partitions=1,
        active_partitions_phase2=(),
    )
    assert pl.phase1_events == 1
    assert pl.phase2_events == 0
