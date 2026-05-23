from fastapi import APIRouter, status

from app.deps import CurrentUser, DbSession
from app.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse
from app.schemas.user import UserOut
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: DbSession):
    return AuthService(db).register(
        email=payload.email, username=payload.username, password=payload.password
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: DbSession):
    service = AuthService(db)
    user = service.authenticate(email=payload.email, password=payload.password)
    access, refresh = service.issue_tokens(user)
    return TokenResponse(access_token=access, refresh_token=refresh)


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: DbSession):
    access, refresh_token = AuthService(db).rotate_refresh_token(payload.refresh_token)
    return TokenResponse(access_token=access, refresh_token=refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(payload: RefreshRequest, db: DbSession):
    AuthService(db).logout(payload.refresh_token)


@router.get("/me", response_model=UserOut)
def me(current_user: CurrentUser):
    return current_user
