import os

DATABASE_URL = os.environ.get("DATABASE_URL", "postgres://localhost/app")
DEBUG = os.environ.get("DEBUG", "false").lower() == "true"
MAX_CONNECTIONS = int(os.environ.get("MAX_CONNECTIONS", "10"))
CACHE_TTL_SECONDS = 300

FEATURE_FLAGS = {
    "new_checkout": False,
    "beta_search": True,
}


def get_flag(name: str) -> bool:
    return FEATURE_FLAGS.get(name, False)
