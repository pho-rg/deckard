from dotenv import load_dotenv
from pathlib import Path
import os
import requests
import json
import argparse
from tqdm import tqdm
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

SHARD_SIZE = 100000
script_dir = Path(__file__).resolve().parent
load_dotenv(script_dir / ".env")
api_key = os.environ["TMDB_API_KEY"]

def store_ids():
    movie_array = []
    target_path = next(script_dir.glob("movie_ids_*.json"))
    with open(target_path, encoding="utf-8") as m:
        for line in m:
            movie_array.append(json.loads(line))
    return movie_array


def shard_path(movie_id):
    shard = movie_id // SHARD_SIZE
    return script_dir / f"raw_movie_data_{shard:05d}.jsonl"


def load_fetched_ids(test=False):
    fetched = set()
    if test:
        path = script_dir / "raw_movie_data_test.jsonl"
        if path.exists():
            with open(path, encoding="utf-8") as f:
                for line in f:
                    try:
                        fetched.add(json.loads(line).get("id"))
                    except json.JSONDecodeError:
                        pass
    else:
        for path in script_dir.glob("raw_movie_data_*.jsonl"):
            with open(path, encoding="utf-8") as f:
                for line in f:
                    try:
                        fetched.add(json.loads(line).get("id"))
                    except json.JSONDecodeError:
                        pass
    return fetched


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


def get_movies(id_array, test=False):
    fetched = load_fetched_ids(test=test)
    todo = [i for i in id_array if i not in fetched]
    session = make_session()

    for i in tqdm(todo, desc="Fetching movies", unit="movie"):
        try:
            response = session.get(
                f"https://api.themoviedb.org/3/movie/{i}",
                params={
                    "api_key": api_key,
                    "append_to_response": "credits,keywords,videos,translations",
                },
                timeout=(10, 30),
            )

            if response.status_code == 404:
                continue
            if not response.ok:
                tqdm.write(f"[skip] id={i} http={response.status_code}")
                continue

            try:
                data = response.json()
            except ValueError:
                tqdm.write(f"[skip] id={i} bad json")
                continue

            if data.get("success") is False:
                continue

            output_path = script_dir / "raw_movie_data_test.jsonl" if test else shard_path(i)
            with open(output_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(data, ensure_ascii=False) + "\n")
                f.flush()

        except KeyboardInterrupt:
            raise
        except Exception as e:
            tqdm.write(f"[skip] id={i} error={e}")
            continue


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", action="store_true", help="Sort by popularity and limit to 100 movies")
    args = parser.parse_args()

    movie_array = store_ids()

    if args.test:
        movie_array.sort(key=lambda x: x.get("popularity", 0), reverse=True)
        movie_array = movie_array[:100]

    id_array = [m.get("id") for m in movie_array]
    get_movies(id_array, test=args.test)