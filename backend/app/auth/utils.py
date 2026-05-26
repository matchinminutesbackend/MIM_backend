import bcrypt
from jose import jwt, JWTError
from datetime import datetime, timedelta, timezone
from app.config import settings

ALGORITHM = "HS256"
_BCRYPT_MAX_BYTES = 72  # bcrypt algorithm limit


def _to_bytes(password: str) -> bytes:
    """bcrypt has a hard 72-byte limit — truncate safely on UTF-8 boundary."""
    data = password.encode("utf-8")
    if len(data) <= _BCRYPT_MAX_BYTES:
        return data
    # Truncate but avoid splitting a multi-byte UTF-8 char
    truncated = data[:_BCRYPT_MAX_BYTES]
    while truncated and (truncated[-1] & 0xC0) == 0x80:
        truncated = truncated[:-1]
    return truncated


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_to_bytes(password), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(_to_bytes(plain), hashed.encode("utf-8"))
    except ValueError:
        return False


def create_token(user_id: str, email: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "email": email,
        "iat": now,
        "exp": now + timedelta(days=settings.jwt_expire_days),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    except JWTError as e:
        raise ValueError(str(e))
