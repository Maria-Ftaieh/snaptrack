"""Pure statistics functions over score logs.

A "log" is any object with `.score: int` and `.recorded_at: datetime` (timezone-aware).
All math is done in UTC; hourly bucketing optionally shifts by a fixed minute offset
so a client in another timezone can request its local-hour distribution.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Iterable, Protocol


class _LogLike(Protocol):
    score: int
    recorded_at: datetime


@dataclass(frozen=True)
class PeriodStats:
    delta: int
    daily_avg: float
    period_start: datetime
    period_end: datetime


def _sorted(logs: Iterable[_LogLike]) -> list[_LogLike]:
    return sorted(logs, key=lambda l: l.recorded_at)


def _score_at_or_before(logs: list[_LogLike], t: datetime) -> int | None:
    """Last known score at time <= t, or None if none exists."""
    best: int | None = None
    for l in logs:
        if l.recorded_at <= t:
            best = l.score
        else:
            break
    return best


def delta_in_period(logs: list[_LogLike], period_start: datetime, period_end: datetime) -> int:
    """Delta = score at period_end − score at period_start.

    Uses the last known score at-or-before each boundary. If the user has no
    history before period_start, falls back to the first in-period log as the
    baseline (so we still report something rather than zero).
    Clamped to >= 0 since snapscore is monotonic.
    """
    if not logs:
        return 0

    end_score = _score_at_or_before(logs, period_end)
    if end_score is None:
        return 0

    start_score = _score_at_or_before(logs, period_start)
    if start_score is None:
        in_period = [l for l in logs if period_start <= l.recorded_at <= period_end]
        if len(in_period) < 2:
            return 0
        start_score = in_period[0].score

    return max(0, end_score - start_score)


def period_stats(
    logs: list[_LogLike], now: datetime, days: int
) -> PeriodStats:
    period_end = now
    period_start = now - timedelta(days=days)
    delta = delta_in_period(logs, period_start, period_end)
    daily_avg = delta / days if days > 0 else 0.0
    return PeriodStats(delta=delta, daily_avg=daily_avg,
                       period_start=period_start, period_end=period_end)


def period_over_period_pct(
    logs: list[_LogLike], now: datetime, days: int
) -> float | None:
    """% change between [now-days, now] and the prior [now-2*days, now-days] window."""
    current = delta_in_period(logs, now - timedelta(days=days), now)
    prior = delta_in_period(
        logs, now - timedelta(days=2 * days), now - timedelta(days=days)
    )
    if prior == 0:
        return None
    return round((current - prior) / prior * 100, 2)


def _walk_hour_chunks(start: datetime, end: datetime, tz_offset_minutes: int):
    """Yield (local_hour, seconds_in_bucket) chunks between two times.

    The local hour is computed by shifting UTC by the given offset so a client
    in UTC+3 sees its own day's hour buckets.
    """
    if end <= start:
        return
    offset = timedelta(minutes=tz_offset_minutes)
    cur = start
    while cur < end:
        local = cur + offset
        next_hour_local = local.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
        next_boundary = next_hour_local - offset
        chunk_end = min(next_boundary, end)
        seconds = (chunk_end - cur).total_seconds()
        if seconds > 0:
            yield local.hour, seconds
        cur = chunk_end


def hourly_activity(logs: list[_LogLike], tz_offset_minutes: int = 0) -> list[tuple[int, float]]:
    """For each hour 0..23 (in the requested local timezone offset), return the
    average snap-rate (snaps per hour) across all observed time spent in that
    hour bucket.
    """
    logs = _sorted(logs)
    snaps_in_hour = [0.0] * 24
    seconds_in_hour = [0.0] * 24

    for prev, cur in zip(logs, logs[1:]):
        delta_score = max(0, cur.score - prev.score)
        total_seconds = (cur.recorded_at - prev.recorded_at).total_seconds()
        if total_seconds <= 0:
            continue
        rate_per_sec = delta_score / total_seconds
        for hour, secs in _walk_hour_chunks(prev.recorded_at, cur.recorded_at, tz_offset_minutes):
            snaps_in_hour[hour] += rate_per_sec * secs
            seconds_in_hour[hour] += secs

    out: list[tuple[int, float]] = []
    for h in range(24):
        avg = (snaps_in_hour[h] / (seconds_in_hour[h] / 3600.0)) if seconds_in_hour[h] > 0 else 0.0
        out.append((h, round(avg, 3)))
    return out


def time_series(logs: list[_LogLike], since: datetime | None = None) -> list[tuple[datetime, int]]:
    logs = _sorted(logs)
    if since is not None:
        logs = [l for l in logs if l.recorded_at >= since]
    return [(l.recorded_at, l.score) for l in logs]


def daily_activity(
    logs: list[_LogLike], now: datetime, days: int = 14, tz_offset_minutes: int = 0
) -> list[tuple[datetime, int]]:
    """For each of the last `days` days (in the requested local timezone),
    return (day_start_utc, snaps_in_day). Oldest first."""
    offset = timedelta(minutes=tz_offset_minutes)
    local_now = now + offset
    local_today_start = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
    out: list[tuple[datetime, int]] = []
    for i in range(days - 1, -1, -1):
        local_day_start = local_today_start - timedelta(days=i)
        local_day_end = local_day_start + timedelta(days=1)
        day_start_utc = local_day_start - offset
        day_end_utc = local_day_end - offset
        snaps = delta_in_period(logs, day_start_utc, day_end_utc)
        out.append((day_start_utc, snaps))
    return out


def weekly_activity(
    logs: list[_LogLike], now: datetime, weeks: int = 8, tz_offset_minutes: int = 0
) -> list[tuple[datetime, int]]:
    """For each of the last `weeks` ISO weeks (Mon start, local timezone),
    return (week_start_utc, snaps_in_week). Oldest first."""
    offset = timedelta(minutes=tz_offset_minutes)
    local_now = now + offset
    local_midnight = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
    this_monday_local = local_midnight - timedelta(days=local_now.weekday())
    out: list[tuple[datetime, int]] = []
    for i in range(weeks - 1, -1, -1):
        local_week_start = this_monday_local - timedelta(weeks=i)
        local_week_end = local_week_start + timedelta(weeks=1)
        week_start_utc = local_week_start - offset
        week_end_utc = local_week_end - offset
        snaps = delta_in_period(logs, week_start_utc, week_end_utc)
        out.append((week_start_utc, snaps))
    return out


def utcnow() -> datetime:
    return datetime.now(timezone.utc)
