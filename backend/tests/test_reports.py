import io
import json
from unittest.mock import MagicMock, patch

import pytest
from app.main import create_app


@pytest.fixture
def app():
    test_app = create_app()
    test_app.config["TESTING"] = True
    return test_app


@pytest.fixture
def client(app):
    return app.test_client()


def test_generate_report_success(client):
    """Test successful Lambda invocation returning 200 with report details."""
    lambda_payload = {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "status": "success",
            "message": "Report generated successfully",
            "report_url": "https://expense-tracker-bucket-yd2026.s3.amazonaws.com/reports/expense-report-test.json",
            "report_key": "reports/expense-report-test.json",
            "generated_at": "2026-09-27T16:00:00Z",
            "expense_count": 5,
            "total_amount": 1500.50,
        }),
    }

    mock_payload_stream = io.BytesIO(json.dumps(lambda_payload).encode("utf-8"))
    mock_response = {
        "StatusCode": 200,
        "Payload": mock_payload_stream,
    }

    with patch("app.routes.get_lambda_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.invoke.return_value = mock_response
        mock_get_client.return_value = mock_client

        resp = client.post("/api/reports", json={})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data["status"] == "success"
        assert data["report_url"].startswith("https://")
        assert data["expense_count"] == 5
        assert data["total_amount"] == 1500.50
        assert data["report_key"] == "reports/expense-report-test.json"


def test_generate_report_function_error(client):
    """Test Lambda unhandled FunctionError returns 502 without leaking internals."""
    error_payload = io.BytesIO(b'{"errorMessage": "Process crashed", "errorType": "RuntimeError"}')
    mock_response = {
        "StatusCode": 200,
        "FunctionError": "Unhandled",
        "Payload": error_payload,
    }

    with patch("app.routes.get_lambda_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.invoke.return_value = mock_response
        mock_get_client.return_value = mock_client

        resp = client.post("/api/reports", json={})
        assert resp.status_code == 502
        data = resp.get_json()
        assert data == {"error": "Failed to generate report"}


def test_generate_report_invocation_exception(client):
    """Test Lambda client exception returns 500 without leaking stack trace."""
    with patch("app.routes.get_lambda_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.invoke.side_effect = Exception("AWS service unreachable")
        mock_get_client.return_value = mock_client

        resp = client.post("/api/reports", json={})
        assert resp.status_code == 500
        data = resp.get_json()
        assert data == {"error": "Report generation service unavailable"}


def test_generate_report_invalid_json_payload(client):
    """Test corrupted or invalid JSON from Lambda returns 502."""
    corrupted_payload = io.BytesIO(b"Not valid JSON at all")
    mock_response = {
        "StatusCode": 200,
        "Payload": corrupted_payload,
    }

    with patch("app.routes.get_lambda_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.invoke.return_value = mock_response
        mock_get_client.return_value = mock_client

        resp = client.post("/api/reports", json={})
        assert resp.status_code == 502
        data = resp.get_json()
        assert data == {"error": "Failed to generate report"}


def test_generate_report_lambda_internal_error_status(client):
    """Test when Lambda returns a formatted error status dictionary, it maps to 502."""
    lambda_payload = {
        "statusCode": 500,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "status": "error",
            "message": "Database connection timeout",
        }),
    }

    mock_payload_stream = io.BytesIO(json.dumps(lambda_payload).encode("utf-8"))
    mock_response = {
        "StatusCode": 200,
        "Payload": mock_payload_stream,
    }

    with patch("app.routes.get_lambda_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.invoke.return_value = mock_response
        mock_get_client.return_value = mock_client

        resp = client.post("/api/reports", json={})
        assert resp.status_code == 502
        data = resp.get_json()
        assert data == {"error": "Failed to generate report"}


def test_generate_report_rate_limit(app):
    """Test that rate limiting is configured and active on /api/reports."""
    from app.limiter import limiter
    prev_enabled = limiter.enabled
    limiter.enabled = True
    try:
        test_client = app.test_client()

        lambda_payload = {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"status": "success", "report_url": "https://s3.example.com"}),
        }

        with patch("app.routes.get_lambda_client") as mock_get_client:
            mock_client = MagicMock()
            mock_client.invoke.side_effect = lambda **kwargs: {
                "StatusCode": 200,
                "Payload": io.BytesIO(json.dumps(lambda_payload).encode("utf-8")),
            }
            mock_get_client.return_value = mock_client

            # The route limit is "10 per second; 30 per minute"
            # Firing 12 rapid requests in succession should trigger 429
            statuses = []
            for _ in range(12):
                resp = test_client.post("/api/reports", json={})
                statuses.append(resp.status_code)

            assert 429 in statuses
    finally:
        limiter.enabled = prev_enabled

