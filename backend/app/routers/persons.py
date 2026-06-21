from fastapi import APIRouter, HTTPException, Query, status

from app.deps import CurrentUser, DbSession
from app.schemas.movie import MovieCard, PagedPersons, PersonCard
from app.services.movie_service import MovieService

router = APIRouter(prefix="/persons", tags=["persons"])


@router.get("/search", response_model=PagedPersons)
def search_persons(
    db: DbSession,
    current_user: CurrentUser,
    q: str = Query(min_length=1, max_length=200, description="Search query"),
    page: int = Query(default=1, ge=1, le=500),
):
    # DB-backed: searches our catalogue's persons (cast & crew), no TMDB call.
    return MovieService(db).search_persons(q, page=page)


@router.get("/{person_id}", response_model=PersonCard)
def get_person(person_id: int, db: DbSession, current_user: CurrentUser):
    person = MovieService(db).get_person(person_id)
    if person is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Person not found")
    return person


@router.get("/{person_id}/filmography", response_model=list[MovieCard])
def person_filmography(
    person_id: int, db: DbSession, current_user: CurrentUser
):
    return MovieService(db).person_filmography(
        person_id, language=current_user.language
    )
