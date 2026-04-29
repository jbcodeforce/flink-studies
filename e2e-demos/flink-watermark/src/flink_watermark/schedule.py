"""Event-time helpers for the two-phase producer (see SPEC: last window [T, T+size) with T=50s)."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

# Fixed story clock: all event times are UTC relative to this instant.
BASE_UTC = datetime(2020, 1, 1, 0, 0, 0, tzinfo=timezone.utc)

# Tumble size in the SQL job (keep in sync with sql/*.sql).
WINDOW_SECONDS = 10

# Last window of interest for the write-up: [50, 60) relative to BASE_UTC.
TARGET_WINDOW_START_SEC = 50
TARGET_WINDOW_END_SEC = 60


@dataclass(frozen=True)
class ProducerPlan:
    """How many events each phase emits (for tests and logging)."""

    phase1_end_inclusive_sec: int
    phase2_start_sec: int
    phase2_end_inclusive_sec: int
    num_partitions: int
    active_partitions_phase2: tuple[int, ...]

    @property
    def phase1_events(self) -> int:
        n = self.phase1_end_inclusive_sec + 1
        return n * self.num_partitions

    @property
    def phase2_events(self) -> int:
        if self.phase2_start_sec > self.phase2_end_inclusive_sec:
            return 0
        n = self.phase2_end_inclusive_sec - self.phase2_start_sec + 1
        return n * len(self.active_partitions_phase2)


def event_time_at_offset(base: datetime, offset_sec: int) -> datetime:
    if base.tzinfo is None:
        msg = "base must be timezone-aware (UTC)"
        raise ValueError(msg)
    return base + timedelta(seconds=int(offset_sec))


def format_event_time_iso(ts: datetime) -> str:
    """Return an ISO-8601 string that Flink JSON + TIMESTAMP(3) accept. """
    if ts.tzinfo is None:
        msg = "ts must be timezone-aware"
        raise ValueError(msg)
    s = ts.astimezone(timezone.utc).isoformat(timespec="milliseconds")
    if s.endswith("+00:00"):
        return s.replace("+00:00", "Z")
    return s


def default_plan() -> ProducerPlan:
    return ProducerPlan(
        phase1_end_inclusive_sec=20,
        phase2_start_sec=21,
        # Stop at 59s so the last in-window second for [50, 60) is 59; 60s would fall into the next tumble.
        phase2_end_inclusive_sec=59,
        num_partitions=4,
        active_partitions_phase2=(0, 1),
    )


def events_for_target_window_included(
    plan: ProducerPlan,
    target_start: int = TARGET_WINDOW_START_SEC,
    target_end: int = TARGET_WINDOW_END_SEC,
) -> int:
    """Count events whose event_time falls in [target_start, target_end) under the plan."""
    count = 0
    for t in range(0, plan.phase1_end_inclusive_sec + 1):
        for _p in range(plan.num_partitions):
            if target_start <= t < target_end:
                count += 1
    for t in range(plan.phase2_start_sec, plan.phase2_end_inclusive_sec + 1):
        for _p in plan.active_partitions_phase2:
            if target_start <= t < target_end:
                count += 1
    return count
