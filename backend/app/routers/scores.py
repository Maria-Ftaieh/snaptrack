from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import require_api_key
from ..database import get_db
from ..models import ScoreLog, User
from ..schemas import ScoreCreate, ScoreOut


router = APIRouter(prefix="/users/{user_id}/scores", tags=["scores"], dependencies=[Depends(require_api_key)])


@router.post("", response_model=ScoreOut, status_code=status.HTTP_201_CREATED)
def create_score(user_id: int, payload: ScoreCreate, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    log = ScoreLog(
        user_id=user_id,
        score=payload.score,
        **({"recorded_at": payload.recorded_at} if payload.recorded_at else {}),
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


@router.get("", response_model=list[ScoreOut])
def list_scores(
    user_id: int,
    from_: datetime | None = Query(default=None, alias="from"),
    to: datetime | None = Query(default=None),
    limit: int | None = Query(default=None, ge=1, le=500),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    stmt = select(ScoreLog).where(ScoreLog.user_id == user_id)
    if from_ is not None:
        stmt = stmt.where(ScoreLog.recorded_at >= from_)
    if to is not None:
        stmt = stmt.where(ScoreLog.recorded_at <= to)
    stmt = stmt.order_by(ScoreLog.recorded_at.desc())
    if limit is not None:
        stmt = stmt.limit(limit)
    return db.scalars(stmt).all()


@router.delete("/{score_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_score(user_id: int, score_id: int, db: Session = Depends(get_db)):
    log = db.get(ScoreLog, score_id)
    if log is None or log.user_id != user_id:
        raise HTTPException(404, "Score not found")
    db.delete(log)
    db.commit()
    return None
