import base64
import hashlib
import hmac
import json
import os
import secrets
import time


SECRET_KEY = os.getenv("SECRET_KEY", "corestream-mvp-local-key").encode()


def _b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode().rstrip("=")


def _unb64(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def hash_password(password: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120_000)
    return f"{salt}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    salt, expected = stored.split("$", 1)
    actual = hash_password(password, salt).split("$", 1)[1]
    return hmac.compare_digest(actual, expected)


def create_access_token(user_id: str, minutes: int = 120) -> str:
    header = _b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = {"sub": user_id, "exp": int(time.time()) + minutes * 60}
    body = _b64(json.dumps(payload).encode())
    unsigned = f"{header}.{body}"
    signature = _b64(hmac.new(SECRET_KEY, unsigned.encode(), hashlib.sha256).digest())
    return f"{unsigned}.{signature}"


def read_access_token(token: str) -> str | None:
    try:
        header, body, signature = token.split(".", 2)
        unsigned = f"{header}.{body}"
        expected = _b64(hmac.new(SECRET_KEY, unsigned.encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(signature, expected):
            return None
        metadata = json.loads(_unb64(header).decode())
        if metadata.get("alg") != "HS256" or metadata.get("typ") != "JWT":
            return None
        payload = json.loads(_unb64(body).decode())
        if int(payload["exp"]) < int(time.time()):
            return None
        return str(payload["sub"])
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        return None


def create_refresh_token() -> str:
    return secrets.token_urlsafe(48)
