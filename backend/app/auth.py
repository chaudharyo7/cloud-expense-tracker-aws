import json
import logging
import time
import urllib.request
from functools import wraps

import jwt
from flask import g, jsonify, request
from jwt.api_jwk import PyJWKSet

from .config import (
    get_cognito_client_id,
    get_cognito_region,
    get_cognito_user_pool_id,
    is_auth_enabled,
)

logger = logging.getLogger(__name__)

# In-memory cache for Cognito JWKS
_JWKS_CACHE = None
_JWKS_LAST_FETCH = 0
JWKS_CACHE_TTL = 3600  # Cache keys for 1 hour


def get_cognito_issuer() -> str:
    """Returns the Cognito User Pool token issuer URL."""
    region = get_cognito_region()
    user_pool_id = get_cognito_user_pool_id()
    if not user_pool_id:
        raise ValueError("COGNITO_USER_POOL_ID is not configured")
    return f"https://cognito-idp.{region}.amazonaws.com/{user_pool_id}"


def get_cognito_jwks_url() -> str:
    """Returns the Cognito JWKS endpoint URL."""
    return f"{get_cognito_issuer()}/.well-known/jwks.json"


def clear_jwks_cache():
    """Clears the cached JWKS (primarily for testing and cache invalidation)."""
    global _JWKS_CACHE, _JWKS_LAST_FETCH
    _JWKS_CACHE = None
    _JWKS_LAST_FETCH = 0


def get_jwks(jwks_url: str = None, force_refresh: bool = False) -> PyJWKSet:
    """
    Fetches and caches the Cognito JWKS keys in memory.
    Refreshes automatically when cache TTL expires or force_refresh is requested.
    """
    global _JWKS_CACHE, _JWKS_LAST_FETCH
    now = time.time()

    if _JWKS_CACHE is not None and not force_refresh:
        if now - _JWKS_LAST_FETCH < JWKS_CACHE_TTL:
            return _JWKS_CACHE

    url = jwks_url or get_cognito_jwks_url()
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "cloud-expense-tracker-backend"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        _JWKS_CACHE = PyJWKSet.from_dict(data)
        _JWKS_LAST_FETCH = now
        return _JWKS_CACHE


def verify_cognito_jwt(token: str) -> dict:
    """
    Validates an incoming Amazon Cognito JWT:
    - Inspects unverified header for key ID ('kid') and RS256 algorithm.
    - Resolves public key from cached JWKS (with single refresh on cache miss).
    - Validates signature, expiration (exp), and issuer (iss).
    - Validates token_use ('id' or 'access').
    - Validates audience or client_id against configured Cognito Client ID.
    - Never echoes sensitive token contents or internal details.
    
    Returns decoded token payload if valid.
    Raises jwt.PyJWTError or ValueError on validation failure.
    """
    try:
        header = jwt.get_unverified_header(token)
    except Exception as e:
        raise jwt.DecodeError("Malformed token header") from e

    kid = header.get("kid")
    if not kid:
        raise jwt.DecodeError("Token header missing 'kid'")

    alg = header.get("alg")
    if alg != "RS256":
        raise jwt.InvalidAlgorithmError(f"Unsupported algorithm: {alg}")

    # Fetch public keys from cached JWKS
    jwks = get_jwks()
    try:
        signing_key = jwks[kid]
    except KeyError:
        # Refresh cache once in case of recent Cognito key rotation
        jwks = get_jwks(force_refresh=True)
        try:
            signing_key = jwks[kid]
        except KeyError:
            raise jwt.InvalidTokenError("Key ID not found in JWKS")

    # Validate signature, expiration, and issuer
    expected_issuer = get_cognito_issuer()
    payload = jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        issuer=expected_issuer,
        options={
            "verify_signature": True,
            "verify_exp": True,
            "verify_iss": True,
            "verify_aud": False,  # Custom verification for ID vs Access token below
        },
    )

    # Validate token_use
    token_use = payload.get("token_use")
    if token_use not in ("id", "access"):
        raise jwt.InvalidTokenError("Invalid token_use claim")

    # Validate client ID / audience where applicable
    expected_client_id = get_cognito_client_id()
    if expected_client_id:
        token_client = (
            payload.get("aud") if token_use == "id" else payload.get("client_id")
        )
        if not token_client:
            token_client = payload.get("client_id") or payload.get("aud")

        if token_client != expected_client_id:
            raise jwt.InvalidTokenError("Token audience/client_id mismatch")

    return payload


def require_auth(fn):
    """
    Decorator to protect Flask routes with Cognito JWT authentication.
    - If AUTH_ENABLED=false: bypasses authentication for local development.
    - If AUTH_ENABLED=true: validates Bearer JWT token from Authorization header.
    - Rejects missing, malformed, expired, or invalid tokens with HTTP 401.
    - Preserves endpoint function metadata using functools.wraps.
    """
    @wraps(fn)
    def decorated(*args, **kwargs):
        if not is_auth_enabled():
            g.current_user = {
                "sub": "local-dev-user",
                "email": "dev@example.com",
                "auth_disabled": True,
            }
            return fn(*args, **kwargs)

        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return jsonify({"error": "Unauthorized"}), 401

        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            return jsonify({"error": "Unauthorized"}), 401

        token = parts[1]
        try:
            payload = verify_cognito_jwt(token)
            g.current_user = payload
        except Exception as e:
            logger.warning("Authentication failed: %s", str(e))
            return jsonify({"error": "Unauthorized"}), 401

        return fn(*args, **kwargs)

    return decorated
