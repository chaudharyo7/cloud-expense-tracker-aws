import json
import time
from unittest.mock import MagicMock, patch

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from flask import Flask
from jwt.algorithms import RSAAlgorithm

from app.auth import clear_jwks_cache, get_jwks, verify_cognito_jwt
from app.limiter import limiter
from app.routes import api

TEST_REGION = "ap-south-1"
TEST_USER_POOL_ID = "ap-south-1_testPool123"
TEST_CLIENT_ID = "test-app-client-id-456"
TEST_ISSUER = f"https://cognito-idp.{TEST_REGION}.amazonaws.com/{TEST_USER_POOL_ID}"


@pytest.fixture(autouse=True)
def reset_jwks():
    """Reset the JWKS cache before and after every test."""
    clear_jwks_cache()
    yield
    clear_jwks_cache()


@pytest.fixture(scope="session")
def rsa_keys():
    """Generate RSA key pair for testing valid signatures."""
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()

    jwk_dict = json.loads(RSAAlgorithm.to_jwk(public_key))
    jwk_dict["kid"] = "valid-kid-1"
    jwk_dict["alg"] = "RS256"
    jwk_dict["use"] = "sig"

    jwks_data = {"keys": [jwk_dict]}
    return private_key, public_key, jwk_dict, jwks_data


@pytest.fixture(scope="session")
def untrusted_rsa_keys():
    """Generate a separate RSA key pair to simulate invalid/untrusted signatures."""
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private_key


@pytest.fixture
def mock_jwks_fetch(rsa_keys):
    """Mocks urllib.request.urlopen to return the test JWKS without external network calls."""
    _, _, _, jwks_data = rsa_keys
    jwks_bytes = json.dumps(jwks_data).encode("utf-8")

    with patch("urllib.request.urlopen") as mock_urlopen:
        mock_response = MagicMock()
        mock_response.read.return_value = jwks_bytes
        mock_response.__enter__.return_value = mock_response
        mock_urlopen.return_value = mock_response
        yield mock_urlopen


@pytest.fixture
def test_app():
    """Creates a Flask test application with the API blueprint registered."""
    app = Flask(__name__)
    app.config["TESTING"] = True
    app.config["RATELIMIT_ENABLED"] = False
    limiter.init_app(app)
    app.register_blueprint(api, url_prefix="/api")
    return app


@pytest.fixture
def client(test_app):
    return test_app.test_client()


def create_token(
    private_key,
    kid="valid-kid-1",
    sub="test-user-sub-123",
    email="user@example.com",
    token_use="id",
    aud=TEST_CLIENT_ID,
    client_id=TEST_CLIENT_ID,
    iss=TEST_ISSUER,
    expires_in=3600,
):
    """Helper to mint test JWTs signed with RS256."""
    now = int(time.time())
    payload = {
        "sub": sub,
        "email": email,
        "token_use": token_use,
        "iss": iss,
        "exp": now + expires_in,
        "iat": now,
    }
    if token_use == "id":
        payload["aud"] = aud
    else:
        payload["client_id"] = client_id

    headers = {"kid": kid, "alg": "RS256"}
    return jwt.encode(payload, private_key, algorithm="RS256", headers=headers)


# ==============================================================================
# 1. Health endpoint test (Public, completely unauthenticated)
# ==============================================================================
def test_health_without_token_returns_200(client, monkeypatch):
    """GET /api/health must remain completely public without token even when AUTH_ENABLED=true."""
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)

    resp = client.get("/api/health")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data == {"status": "ok", "service": "expense-api"}


# ==============================================================================
# 2. Missing Authorization header test -> 401
# ==============================================================================
def test_missing_auth_header_returns_401(client, monkeypatch):
    """Protected endpoints must reject requests with missing Authorization header with 401."""
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)

    # Test GET /api/expenses
    resp = client.get("/api/expenses")
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}

    # Test POST /api/expenses
    resp = client.post("/api/expenses", json={"amount": 50, "category": "Food"})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}

    # Test DELETE /api/expenses/<id>
    resp = client.delete("/api/expenses/1")
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}

    # Test GET /api/infrastructure
    resp = client.get("/api/infrastructure")
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


# ==============================================================================
# 3. Malformed token tests -> 401
# ==============================================================================
@pytest.mark.parametrize(
    "auth_header",
    [
        "Basic dXNlcjpwYXNz",                  # Non-Bearer scheme
        "Bearer",                              # Bearer with missing token
        "Bearer ",                             # Bearer with empty token
        "Bearer a b c",                        # Extra parts
        "Bearer not-a-jwt",                    # Completely invalid JWT structure
        "Bearer abc.def",                      # Missing signature component
    ],
)
def test_malformed_auth_header_or_token_returns_401(client, monkeypatch, auth_header):
    """Malformed headers or invalid token formats must return 401."""
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)

    resp = client.get("/api/expenses", headers={"Authorization": auth_header})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


def test_token_missing_kid_header_returns_401(client, monkeypatch, rsa_keys, mock_jwks_fetch):
    """Token without 'kid' in header must return 401."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)

    # Encode without 'kid'
    token = jwt.encode(
        {"sub": "123", "iss": TEST_ISSUER, "exp": int(time.time()) + 3600},
        priv,
        algorithm="RS256",
        headers={},
    )
    resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


def test_token_unsupported_algorithm_returns_401(client, monkeypatch):
    """Token with algorithm other than RS256 must return 401."""
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)

    # Token signed with HS256 symmetric secret
    token = jwt.encode(
        {"sub": "123", "iss": TEST_ISSUER, "exp": int(time.time()) + 3600},
        "a-secret-key-that-is-at-least-32-bytes-long",
        algorithm="HS256",
        headers={"kid": "some-kid"},
    )
    resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


# ==============================================================================
# 4. Invalid signature test -> 401
# ==============================================================================
def test_invalid_signature_returns_401(
    client, monkeypatch, untrusted_rsa_keys, mock_jwks_fetch
):
    """Token signed by an untrusted key not matching JWKS must return 401."""
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    # Signed with untrusted key, but claiming kid='valid-kid-1'
    token = create_token(untrusted_rsa_keys, kid="valid-kid-1")

    resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


# ==============================================================================
# 5. Expired token test -> 401
# ==============================================================================
def test_expired_token_returns_401(client, monkeypatch, rsa_keys, mock_jwks_fetch):
    """Token with past expiration timestamp (exp) must return 401."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    token = create_token(priv, expires_in=-60)  # Expired 60s ago

    resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


# ==============================================================================
# 6. Valid Cognito token test -> Allowed
# ==============================================================================
def test_valid_cognito_id_token_allowed(client, monkeypatch, rsa_keys, mock_jwks_fetch):
    """Valid Cognito ID token must be accepted by protected endpoints."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    token = create_token(priv, token_use="id")

    # Mock DB connection for /api/expenses
    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        assert resp.get_json() == []


def test_valid_cognito_access_token_allowed(
    client, monkeypatch, rsa_keys, mock_jwks_fetch
):
    """Valid Cognito Access token (using client_id claim) must be accepted."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    token = create_token(priv, token_use="access")

    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        assert resp.get_json() == []


def test_issuer_mismatch_returns_401(client, monkeypatch, rsa_keys, mock_jwks_fetch):
    """Token with issuer other than the configured User Pool must return 401."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    token = create_token(priv, iss="https://cognito-idp.ap-south-1.amazonaws.com/wrong-pool")

    resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


def test_client_id_mismatch_returns_401(client, monkeypatch, rsa_keys, mock_jwks_fetch):
    """Token with mismatched audience/client_id must return 401."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    token = create_token(priv, aud="wrong-client-id", client_id="wrong-client-id")

    resp = client.get("/api/expenses", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401
    assert resp.get_json() == {"error": "Unauthorized"}


# ==============================================================================
# 7. Local AUTH_ENABLED=false behavior
# ==============================================================================
def test_local_auth_disabled_allows_requests_without_token(client, monkeypatch):
    """When AUTH_ENABLED=false, protected routes must allow unauthenticated requests."""
    monkeypatch.setenv("AUTH_ENABLED", "false")

    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.get("/api/expenses")
        assert resp.status_code == 200
        assert resp.get_json() == []


# ==============================================================================
# 8. JWKS Caching and Key Rotation test
# ==============================================================================
def test_jwks_caching_and_rotation(monkeypatch, rsa_keys, mock_jwks_fetch):
    """Verifies that JWKS is cached across requests and refreshed upon unknown key ID."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    # First fetch populates cache
    jwks1 = get_jwks()
    assert jwks1["valid-kid-1"].key is not None
    assert mock_jwks_fetch.call_count == 1

    # Second fetch should use cache without invoking urlopen again
    jwks2 = get_jwks()
    assert mock_jwks_fetch.call_count == 1

    # Token verification using cached key
    token = create_token(priv)
    payload = verify_cognito_jwt(token)
    assert payload["sub"] == "test-user-sub-123"
    assert mock_jwks_fetch.call_count == 1

    # An unknown kid triggers force_refresh=True (1 more urlopen call)
    unknown_token = create_token(priv, kid="unknown-kid-999")
    with pytest.raises(jwt.InvalidTokenError):
        verify_cognito_jwt(unknown_token)

    # Call count increased because of rotation retry
    assert mock_jwks_fetch.call_count == 2


# ==============================================================================
# 9. All Protected Endpoints with Valid Token
# ==============================================================================
def test_all_protected_endpoints_succeed_with_valid_token(
    client, monkeypatch, rsa_keys, mock_jwks_fetch
):
    """Verifies POST /api/expenses, DELETE /api/expenses/<id>, and GET /api/infrastructure with valid token."""
    priv, _, _, _ = rsa_keys
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", TEST_USER_POOL_ID)
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", TEST_CLIENT_ID)

    token = create_token(priv, token_use="id")
    headers = {"Authorization": f"Bearer {token}"}

    # 1. POST /api/expenses
    from datetime import date, datetime

    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = {
            "id": 1,
            "amount": 25.50,
            "category": "Office",
            "description": "Supplies",
            "expense_date": date(2026, 9, 27),
            "created_at": datetime(2026, 9, 27, 10, 0, 0),
        }
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.post(
            "/api/expenses",
            json={
                "amount": 25.50,
                "category": "Office",
                "description": "Supplies",
                "expense_date": "2026-09-27",
            },
            headers=headers,
        )
        assert resp.status_code == 201

    # 2. DELETE /api/expenses/1
    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = {"id": 1}
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.delete("/api/expenses/1", headers=headers)
        assert resp.status_code == 200
        assert resp.get_json() == {"message": "Expense deleted successfully"}

    # 3. GET /api/infrastructure
    with patch("boto3.client") as mock_boto:
        mock_ec2 = MagicMock()
        mock_ec2.describe_instances.return_value = {"Reservations": []}
        mock_boto.return_value = mock_ec2

        resp = client.get("/api/infrastructure", headers=headers)
        assert resp.status_code == 200


# ==============================================================================
# 10. Public Portfolio Safety (Default auth disabled when unset)
# ==============================================================================
def test_public_portfolio_default_auth_disabled_when_unset(
    client, monkeypatch
):
    """When AUTH_ENABLED is unset in environment, it defaults to False so public portfolio visitors can use the app."""
    monkeypatch.delenv("AUTH_ENABLED", raising=False)

    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.get("/api/expenses")
        assert resp.status_code == 200
        assert resp.get_json() == []
