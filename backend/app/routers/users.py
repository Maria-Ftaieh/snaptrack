from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import require_api_key
from ..database import get_db
from ..models import ScoreLog, User
from ..schemas import UserCreate, UserOut, UserWithLatest


router = APIRouter(prefix="/users", tags=["users"], dependencies=[Depends(require_api_key)])


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    user = User(name=payload.name, snapchat_username=payload.snapchat_username)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("", response_model=list[UserWithLatest])
def list_users(db: Session = Depends(get_db)):
    users = db.scalars(select(User).order_by(User.created_at.desc())).all()
    result: list[UserWithLatest] = []
    for u in users:
        latest = db.scalars(
            select(ScoreLog)
            .where(ScoreLog.user_id == u.id)
            .order_by(ScoreLog.recorded_at.desc())
            .limit(1)
        ).first()
        result.append(
            UserWithLatest(
                id=u.id,
                name=u.name,
                snapchat_username=u.snapchat_username,
                created_at=u.created_at,
                latest_score=latest.score if latest else None,
                latest_recorded_at=latest.recorded_at if latest else None,
            )
        )
    return result


@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "User not found")
    db.delete(user)
    db.commit()
    return None
