from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.models.user import User
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.repositories.user_repository import UserRepository
from app.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)


class AuthService:
    def __init__(self, db: Session):
        self.db = db
        self.users = UserRepository(db)
        self.refresh_tokens = RefreshTokenRepository(db)

    def register(self, *, email: str, username: str, password: str) -> User:
        if self.users.get_by_email(email):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Email already registered"
            )
        if self.users.get_by_username(username):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Username already taken"
            )
        return self.users.create(
            email=email, username=username, password_hash=hash_password(password)
        )

    def authenticate(self, *, email: str, password: str) -> User:
        user = self.users.get_by_email(email)
        if not user or not verify_password(password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
            )
        return user

    def issue_tokens(self, user: User) -> tuple[str, str]:
        access = create_access_token(str(user.id))
        refresh = generate_refresh_token()
        expires_at = datetime.now(timezone.utc) + timedelta(
            days=settings.refresh_token_ttl_days
        )
        self.refresh_tokens.create(
            user_id=user.id,
            token_hash=hash_refresh_token(refresh),
            expires_at=expires_at,
        )
        return access, refresh

    def rotate_refresh_token(self, refresh_token: str) -> tuple[str, str]:
        stored = self.refresh_tokens.get_active_by_hash(hash_refresh_token(refresh_token))
        if not stored:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token"
            )
        self.refresh_tokens.revoke(stored)
        user = self.users.get_by_id(stored.user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
            )
        return self.issue_tokens(user)

    def logout(self, refresh_token: str) -> None:
        stored = self.refresh_tokens.get_active_by_hash(hash_refresh_token(refresh_token))
        if stored:
            self.refresh_tokens.revoke(stored)
