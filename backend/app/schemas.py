from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    snapchat_username: Optional[str] = Field(default=None, max_length=100)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    snapchat_username: Optional[str]
    created_at: datetime


class UserWithLatest(UserOut):
    latest_score: Optional[int] = None
    latest_recorded_at: Optional[datetime] = None


class ScoreCreate(BaseModel):
    score: int = Field(ge=0)
    recorded_at: Optional[datetime] = None


class ScoreOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    score: int
    recorded_at: datetime


class PeriodStats(BaseModel):
    delta: int
    daily_avg: float
    period_start: datetime
    period_end: datetime


class TimeSeriesPoint(BaseModel):
    t: datetime
    score: int


class HourlyBucket(BaseModel):
    hour: int
    avg_snaps_per_hour: float


class DailyActivity(BaseModel):
    date: datetime
    snaps: int


class WeeklyActivity(BaseModel):
    week_start: datetime
    snaps: int


class StatsOut(BaseModel):
    current_score: Optional[int] = None
    last_recorded_at: Optional[datetime] = None
    last_7_days: Optional[PeriodStats] = None
    last_30_days: Optional[PeriodStats] = None
    week_over_week_pct: Optional[float] = None
    month_over_month_pct: Optional[float] = None
    time_series: list[TimeSeriesPoint]
    hourly_activity: list[HourlyBucket]
    daily_activity: list[DailyActivity]
    weekly_activity: list[WeeklyActivity]
