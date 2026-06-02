from dotenv import load_dotenv
from pathlib import Path
import os
import json
import requests
from tqdm import tqdm
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

START_DATE = "2026-04-08"
END_DATE = "2026-04-14"

script_dir = Path(__file__).resolve().parent
load_dotenv(script_dir / ".env")
api_key = os.environ["TMDB_API_KEY"]

BASE_URL = "https://api.themoviedb.org/3/movie/changes"


def make_session():
    s = requests.Session()
    retry = Retry(
        total=20,
        connect=20,
        read=20,
        backoff_factor=2,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(["GET"]),
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retry, pool_connections=10, pool_maxsize=10)
    s.mount("https://", adapter)
    s.mount("http://", adapter)
    return s


def get_changed_ids(start_date, end_date):
    session = make_session()
    changed_ids = set()
    page = 1
    total_pages = 1

    with tqdm(desc="Fetching changed IDs", unit="page") as pbar:
        while page <= total_pages:
            response = session.get(
                BASE_URL,
                params={
                    "api_key": api_key,
                    "start_date": start_date,
                    "end_date": end_date,
                    "page": page,
                },
                timeout=(10, 30),
            )

            if not response.ok:
                tqdm.write(f"[skip] page={page} http={response.status_code}")
                break

            try:
                data = response.json()
            except ValueError:
                tqdm.write(f"[skip] page={page} bad json")
                break

            for item in data.get("results", []):
                mid = item.get("id")
                if mid is not None:
                    changed_ids.add(mid)

            total_pages = data.get("total_pages", 1)
            pbar.total = total_pages
            pbar.update(1)
            page += 1

    return changed_ids


def save_ids(ids, start_date, end_date):
    output_file = script_dir / f"changed_movie_ids_{start_date}_to_{end_date}.jsonl"
    with open(output_file, "w", encoding="utf-8") as f:
        for movie_id in sorted(ids):
            f.write(json.dumps({"id": movie_id}) + "\n")
    return output_file


if __name__ == "__main__":
    ids = get_changed_ids(START_DATE, END_DATE)
    print(f"\n✅ Collected {len(ids)} unique movie IDs")
    out = save_ids(ids, START_DATE, END_DATE)
    print(f"📄 Saved to {out.name}")