from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import stats as stats_mod
from ..auth import require_api_key
from ..database import get_db
from ..models import ScoreLog, User
from ..schemas import (
    DailyActivity,
    HourlyBucket,
    PeriodStats,
    StatsOut,
    TimeSeriesPoint,
    WeeklyActivity,
)


router = APIRouter(prefix="/users/{user_id}/stats", tags=["stats"], dependencies=[Depends(require_api_key)])


@router.get("", response_model=StatsOut)
def get_stats(
    user_id: int,
    tz_offset_minutes: int = Query(default=0, ge=-14 * 60, le=14 * 60),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")

    logs = db.scalars(
        select(ScoreLog)
        .where(ScoreLog.user_id == user_id)
        .order_by(ScoreLog.recorded_at.asc())
    ).all()

    now = stats_mod.utcnow()

    if not logs:
        return StatsOut(
            time_series=[],
            hourly_activity=[HourlyBucket(hour=h, avg_snaps_per_hour=0.0) for h in range(24)],
            daily_activity=[],
            weekly_activity=[],
        )

    p7 = stats_mod.period_stats(logs, now, 7)
    p30 = stats_mod.period_stats(logs, now, 30)

    series_since = now - timedelta(days=30)
    series = stats_mod.time_series(logs, since=series_since)

    hourly = stats_mod.hourly_activity(logs, tz_offset_minutes=tz_offset_minutes)
    daily = stats_mod.daily_activity(logs, now, days=14, tz_offset_minutes=tz_offset_minutes)
    weekly = stats_mod.weekly_activity(logs, now, weeks=8, tz_offset_minutes=tz_offset_minutes)

    last = logs[-1]
    return StatsOut(
        current_score=last.score,
        last_recorded_at=last.recorded_at,
        last_7_days=PeriodStats(delta=p7.delta, daily_avg=round(p7.daily_avg, 2),
                                period_start=p7.period_start, period_end=p7.period_end),
        last_30_days=PeriodStats(delta=p30.delta, daily_avg=round(p30.daily_avg, 2),
                                 period_start=p30.period_start, period_end=p30.period_end),
        week_over_week_pct=stats_mod.period_over_period_pct(logs, now, 7),
        month_over_month_pct=stats_mod.period_over_period_pct(logs, now, 30),
        time_series=[TimeSeriesPoint(t=t, score=s) for t, s in series],
        hourly_activity=[HourlyBucket(hour=h, avg_snaps_per_hour=v) for h, v in hourly],
        daily_activity=[DailyActivity(date=d, snaps=s) for d, s in daily],
        weekly_activity=[WeeklyActivity(week_start=d, snaps=s) for d, s in weekly],
    )
