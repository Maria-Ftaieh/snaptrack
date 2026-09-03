from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from app import stats


@dataclass
class Log:
    score: int
    recorded_at: datetime


UTC = timezone.utc


def _log(score: int, days_ago: float, *, now: datetime) -> Log:
    return Log(score=score, recorded_at=now - timedelta(days=days_ago))


def test_empty_logs_returns_zero_delta():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    assert stats.delta_in_period([], now - timedelta(days=7), now) == 0


def test_delta_uses_score_before_period_start_as_baseline():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [
        _log(10000, 14, now=now),  # before 7d window
        _log(10300, 6, now=now),   # in window
        _log(10500, 1, now=now),   # in window
    ]
    delta = stats.delta_in_period(logs, now - timedelta(days=7), now)
    assert delta == 500  # 10500 - 10000 (last-before-window baseline)


def test_delta_falls_back_to_first_in_period_when_no_history():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [
        _log(10200, 5, now=now),
        _log(10500, 1, now=now),
    ]
    delta = stats.delta_in_period(logs, now - timedelta(days=7), now)
    assert delta == 300


def test_delta_clamps_negative_to_zero():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [
        _log(500, 10, now=now),
        _log(400, 1, now=now),  # user mistyped, looks like a decrease
    ]
    delta = stats.delta_in_period(logs, now - timedelta(days=7), now)
    assert delta == 0


def test_period_stats_daily_avg():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [_log(1000, 14, now=now), _log(1700, 0, now=now)]
    p = stats.period_stats(logs, now, days=7)
    assert p.delta == 700
    assert p.daily_avg == 100.0


def test_period_over_period_pct_positive():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [
        _log(0, 14, now=now),     # boundary of prior window start
        _log(100, 7, now=now),    # boundary of prior/current windows
        _log(250, 0, now=now),    # end of current window
    ]
    # prior delta = 100, current delta = 150 -> +50%
    pct = stats.period_over_period_pct(logs, now, days=7)
    assert pct == 50.0


def test_period_over_period_pct_returns_none_when_prior_zero():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [_log(0, 7, now=now), _log(100, 1, now=now)]
    pct = stats.period_over_period_pct(logs, now, days=7)
    assert pct is None


def test_hourly_activity_distributes_snaps_proportionally():
    # Two logs 2 hours apart at 10:00 and 12:00 UTC, 200 snaps total -> 100/h
    # spread over hour-of-day buckets 10 and 11.
    t0 = datetime(2026, 5, 14, 10, 0, tzinfo=UTC)
    t1 = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [Log(score=1000, recorded_at=t0), Log(score=1200, recorded_at=t1)]
    hourly = dict(stats.hourly_activity(logs))
    assert hourly[10] == 100.0
    assert hourly[11] == 100.0
    assert hourly[12] == 0.0  # nothing observed there


def test_hourly_activity_handles_hour_crossing():
    # 30 min spanning 10:30 -> 11:00 -> 11:30, 60 snaps total = 120 snaps/h rate.
    t0 = datetime(2026, 5, 14, 10, 30, tzinfo=UTC)
    t1 = datetime(2026, 5, 14, 11, 30, tzinfo=UTC)
    logs = [Log(score=0, recorded_at=t0), Log(score=120, recorded_at=t1)]
    hourly = dict(stats.hourly_activity(logs))
    # Both bucket 10 (30min observed) and 11 (30min observed) see rate 120/h.
    assert hourly[10] == 120.0
    assert hourly[11] == 120.0


def test_hourly_activity_tz_offset_shifts_buckets():
    # 10:00-12:00 UTC with +180min offset (UTC+3, Istanbul) -> local 13:00-15:00.
    t0 = datetime(2026, 5, 14, 10, 0, tzinfo=UTC)
    t1 = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [Log(score=0, recorded_at=t0), Log(score=200, recorded_at=t1)]
    hourly = dict(stats.hourly_activity(logs, tz_offset_minutes=180))
    assert hourly[13] == 100.0
    assert hourly[14] == 100.0
    assert hourly[10] == 0.0


def test_time_series_filters_by_since():
    now = datetime(2026, 5, 14, 12, 0, tzinfo=UTC)
    logs = [_log(100, 40, now=now), _log(200, 20, now=now), _log(300, 5, now=now)]
    series = stats.time_series(logs, since=now - timedelta(days=30))
    assert [s for _, s in series] == [200, 300]
