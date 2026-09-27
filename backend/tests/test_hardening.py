import json
from datetime import date, datetime
from unittest.mock import MagicMock, patch

import pytest
from app.main import create_app
from app.limiter import limiter


@pytest.fixture
def app():
    test_app = create_app()
    test_app.config["TESTING"] = True
    return test_app


@pytest.fixture
def client(app):
    return app.test_client()


# ==============================================================================
# 1. POST /api/expenses - Validation & Security Tests
# ==============================================================================
def test_create_expense_valid(client):
    """Valid expense creation returns 201 with saved record."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = {
            "id": 101,
            "amount": 250.75,
            "category": "Food",
            "description": "Lunch meeting",
            "expense_date": date(2026, 9, 27),
            "created_at": datetime(2026, 9, 27, 12, 0, 0),
        }
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.post(
            "/api/expenses",
            json={
                "amount": 250.75,
                "category": "Food",
                "description": "Lunch meeting",
                "expense_date": "2026-09-27",
            },
        )
        assert resp.status_code == 201
        data = resp.get_json()
        assert data["id"] == 101
        assert data["amount"] == 250.75
        assert data["category"] == "Food"


def test_create_expense_category_normalization(client):
    """Category matching is case-insensitive and normalizes to Title Case."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = {
            "id": 102,
            "amount": 100.0,
            "category": "Travel",
            "description": "Metro",
            "expense_date": date(2026, 9, 27),
            "created_at": datetime(2026, 9, 27, 12, 0, 0),
        }
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.post(
            "/api/expenses",
            json={
                "amount": 100,
                "category": "travel",
                "description": "Metro",
                "expense_date": "2026-09-27",
            },
        )
        assert resp.status_code == 201
        # Confirms 'Travel' was passed to DB insert
        call_args = mock_cursor.execute.call_args[0][1]
        assert call_args[1] == "Travel"


def test_create_expense_invalid_category(client):
    """Unapproved category is rejected with 400."""
    resp = client.post(
        "/api/expenses",
        json={
            "amount": 50,
            "category": "Gambling",
            "description": "Test",
            "expense_date": "2026-09-27",
        },
    )
    assert resp.status_code == 400
    assert "Invalid category" in resp.get_json()["error"]


def test_create_expense_missing_fields(client):
    """Missing required fields return 400 with helpful error."""
    resp = client.post(
        "/api/expenses",
        json={"category": "Food", "expense_date": "2026-09-27"},
    )
    assert resp.status_code == 400
    assert "amount is required" in resp.get_json()["error"]


def test_create_expense_negative_or_zero_amount(client):
    """Zero or negative amounts are rejected with 400."""
    resp = client.post(
        "/api/expenses",
        json={
            "amount": 0,
            "category": "Food",
            "description": "Test",
            "expense_date": "2026-09-27",
        },
    )
    assert resp.status_code == 400
    assert "Amount must be between" in resp.get_json()["error"]

    resp2 = client.post(
        "/api/expenses",
        json={
            "amount": -50,
            "category": "Food",
            "description": "Test",
            "expense_date": "2026-09-27",
        },
    )
    assert resp2.status_code == 400


def test_create_expense_excessive_amount(client):
    """Amounts exceeding upper boundary (₹1 Crore) are rejected with 400."""
    resp = client.post(
        "/api/expenses",
        json={
            "amount": 100_000_000,
            "category": "Food",
            "description": "Excessive",
            "expense_date": "2026-09-27",
        },
    )
    assert resp.status_code == 400
    assert "Amount must be between" in resp.get_json()["error"]


def test_create_expense_excessive_description(client):
    """Descriptions exceeding 200 characters are rejected with 400."""
    resp = client.post(
        "/api/expenses",
        json={
            "amount": 100,
            "category": "Food",
            "description": "A" * 201,
            "expense_date": "2026-09-27",
        },
    )
    assert resp.status_code == 400
    assert "exceeds maximum length" in resp.get_json()["error"]


def test_create_expense_invalid_date(client):
    """Malformed dates are rejected with 400."""
    resp = client.post(
        "/api/expenses",
        json={
            "amount": 100,
            "category": "Food",
            "description": "Test",
            "expense_date": "not-a-date",
        },
    )
    assert resp.status_code == 400
    assert "Invalid expense_date format" in resp.get_json()["error"]


def test_create_expense_date_out_of_range(client):
    """Dates far outside reasonable range (2020-2035) are rejected with 400."""
    resp = client.post(
        "/api/expenses",
        json={
            "amount": 100,
            "category": "Food",
            "description": "Test",
            "expense_date": "1999-01-01",
        },
    )
    assert resp.status_code == 400
    assert "expense_date must be between" in resp.get_json()["error"]


def test_create_expense_non_json_content_type(client):
    """Non-JSON Content-Type returns 415 Unsupported Media Type."""
    resp = client.post(
        "/api/expenses",
        data="amount=100&category=Food",
        content_type="application/x-www-form-urlencoded",
    )
    assert resp.status_code == 415


def test_create_expense_unexpected_fields(client):
    """Arbitrary/unexpected fields are rejected to prevent mass-assignment attacks."""
    resp = client.post(
        "/api/expenses",
        json={
            "amount": 100,
            "category": "Food",
            "expense_date": "2026-09-27",
            "admin": True,
            "role": "superuser",
        },
    )
    assert resp.status_code == 400
    assert "Unexpected fields" in resp.get_json()["error"]


def test_create_expense_database_failure(client):
    """Database exception returns sanitized 500 without leaking internals."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_conn.side_effect = Exception("psycopg.OperationalError: Connection refused")
        resp = client.post(
            "/api/expenses",
            json={
                "amount": 50,
                "category": "Food",
                "expense_date": "2026-09-27",
            },
        )
        assert resp.status_code == 500
        assert resp.get_json() == {"error": "Failed to save expense"}


# ==============================================================================
# 2. DELETE /api/expenses/<id> - Validation & Security Tests
# ==============================================================================
def test_delete_expense_valid(client):
    """Valid expense deletion returns 200."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = {"id": 42}
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.delete("/api/expenses/42")
        assert resp.status_code == 200
        assert resp.get_json() == {"message": "Expense deleted successfully"}


def test_delete_expense_not_found(client):
    """Non-existent expense deletion returns 404."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = None
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.delete("/api/expenses/99999")
        assert resp.status_code == 404
        assert resp.get_json() == {"error": "Expense not found"}


def test_delete_expense_invalid_id(client):
    """Negative or zero expense ID returns 400."""
    resp = client.delete("/api/expenses/0")
    assert resp.status_code == 400
    assert resp.get_json() == {"error": "Invalid expense ID"}


def test_delete_expense_database_failure(client):
    """Database failure on delete returns sanitized 500."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_conn.side_effect = Exception("Database disk full")
        resp = client.delete("/api/expenses/1")
        assert resp.status_code == 500
        assert resp.get_json() == {"error": "Failed to delete expense"}


# ==============================================================================
# 3. GET /api/expenses - Query Bounding & Security Tests
# ==============================================================================
def test_list_expenses_bounded_query(client):
    """List expenses query includes LIMIT to prevent memory exhaustion."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []
        mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
            mock_cursor
        )

        resp = client.get("/api/expenses")
        assert resp.status_code == 200
        # Verify LIMIT parameter was passed
        query = mock_cursor.execute.call_args[0][0]
        params = mock_cursor.execute.call_args[0][1]
        assert "LIMIT %s" in query
        assert params == (100,)


def test_list_expenses_database_failure(client):
    """Database failure on list returns sanitized 500."""
    with patch("app.routes.get_connection") as mock_conn:
        mock_conn.side_effect = Exception("Query timeout")
        resp = client.get("/api/expenses")
        assert resp.status_code == 500
        assert resp.get_json() == {"error": "Failed to retrieve expenses"}


# ==============================================================================
# 4. Security Headers & Error Handling Tests
# ==============================================================================
def test_security_headers_present_on_responses(client):
    """Verify all required security headers are attached to responses."""
    resp = client.get("/api/health")
    assert resp.status_code == 200
    assert resp.headers.get("X-Content-Type-Options") == "nosniff"
    assert resp.headers.get("X-Frame-Options") == "DENY"
    assert resp.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"
    assert "max-age=31536000" in resp.headers.get("Strict-Transport-Security", "")
    assert "default-src 'none'" in resp.headers.get("Content-Security-Policy", "")
    assert "no-store" in resp.headers.get("Cache-Control", "")


def test_404_not_found_returns_clean_json(client):
    """Unknown route returns clean JSON 404 without HTML."""
    resp = client.get("/api/nonexistent")
    assert resp.status_code == 404
    assert resp.get_json() == {"error": "Resource not found"}


def test_405_method_not_allowed_returns_clean_json(client):
    """Unsupported HTTP method returns clean JSON 405."""
    resp = client.put("/api/health")
    assert resp.status_code == 405
    assert resp.get_json() == {"error": "Method not allowed"}


# ==============================================================================
# 5. Rate Limiting Tests on POST and DELETE
# ==============================================================================
def test_post_expenses_rate_limiting(app):
    """POST /api/expenses enforces rate limit (2/sec, 20/min)."""
    prev_enabled = limiter.enabled
    limiter.enabled = True
    try:
        test_client = app.test_client()
        with patch("app.routes.get_connection") as mock_conn:
            mock_cursor = MagicMock()
            mock_cursor.fetchone.return_value = {
                "id": 1,
                "amount": 10.0,
                "category": "Food",
                "description": "",
                "expense_date": date(2026, 9, 27),
                "created_at": datetime(2026, 9, 27, 12, 0, 0),
            }
            mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
                mock_cursor
            )

            statuses = []
            for _ in range(5):
                resp = test_client.post(
                    "/api/expenses",
                    json={
                        "amount": 10.0,
                        "category": "Food",
                        "expense_date": "2026-09-27",
                    },
                )
                statuses.append(resp.status_code)

            assert 429 in statuses
    finally:
        limiter.enabled = prev_enabled


def test_delete_expenses_rate_limiting(app):
    """DELETE /api/expenses/<id> enforces rate limit (2/sec, 15/min)."""
    prev_enabled = limiter.enabled
    limiter.enabled = True
    try:
        test_client = app.test_client()
        with patch("app.routes.get_connection") as mock_conn:
            mock_cursor = MagicMock()
            mock_cursor.fetchone.return_value = {"id": 1}
            mock_conn.return_value.__enter__.return_value.cursor.return_value.__enter__.return_value = (
                mock_cursor
            )

            statuses = []
            for i in range(5):
                resp = test_client.delete(f"/api/expenses/{i + 1}")
                statuses.append(resp.status_code)

            assert 429 in statuses
    finally:
        limiter.enabled = prev_enabled
