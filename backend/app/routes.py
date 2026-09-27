import json
import logging
import math
import os
from datetime import date

import boto3
from flask import Blueprint, jsonify, request

from .auth import require_auth
from .db import get_connection
from .limiter import limiter

logger = logging.getLogger(__name__)

api = Blueprint("api", __name__)

_LAMBDA_CLIENT = None

# Validation and policy constraints
ALLOWED_CATEGORIES = frozenset([
    "Food",
    "Travel",
    "Shopping",
    "Education",
    "Bills",
    "Office",
    "Other",
])

MIN_AMOUNT = 0.01
MAX_AMOUNT = 10_000_000.00  # ₹1 Crore limit per transaction
MAX_DESCRIPTION_LENGTH = 200
MIN_DATE = date(2020, 1, 1)
MAX_DATE = date(2035, 12, 31)
MAX_EXPENSES_LIMIT = 100
MAX_EXPENSE_ID = 2_147_483_647  # PostgreSQL 32-bit SERIAL max


def get_lambda_client():
    global _LAMBDA_CLIENT
    if _LAMBDA_CLIENT is None:
        region = os.getenv("AWS_REGION", "ap-south-1")
        _LAMBDA_CLIENT = boto3.client("lambda", region_name=region)
    return _LAMBDA_CLIENT


def validate_expense_input(data):
    """
    Validates expense input payload:
    - Enforces expected JSON object structure and rejects arbitrary keys.
    - Validates category against whitelist.
    - Validates amount boundaries (0.01 <= amount <= 10,000,000.00), finite numeric.
    - Validates description length (<= 200 characters).
    - Validates expense_date format (YYYY-MM-DD) and calendar range (2020-2035).
    """
    if not isinstance(data, dict):
        return None, "Request body must be a valid JSON object"

    allowed_keys = {"amount", "category", "description", "expense_date"}
    extra_keys = set(data.keys()) - allowed_keys
    if extra_keys:
        return None, f"Unexpected fields in request: {', '.join(sorted(extra_keys))}"

    amount_raw = data.get("amount")
    category = data.get("category")
    description = data.get("description", "")
    expense_date_raw = data.get("expense_date")

    if amount_raw in (None, ""):
        return None, "amount is required"
    if not category:
        return None, "category is required"
    if not expense_date_raw:
        return None, "expense_date is required"

    # Category validation
    if not isinstance(category, str):
        return None, "category must be a string"
    category = category.strip()
    # Normalize category capitalization to match allowed categories
    category_match = next(
        (c for c in ALLOWED_CATEGORIES if c.lower() == category.lower()), None
    )
    if not category_match:
        return (
            None,
            f"Invalid category. Allowed categories: {', '.join(sorted(ALLOWED_CATEGORIES))}",
        )
    category = category_match

    # Amount validation
    try:
        amount = float(amount_raw)
    except (ValueError, TypeError):
        return None, "Invalid amount format"

    if math.isnan(amount) or math.isinf(amount):
        return None, "Invalid amount value"

    if not (MIN_AMOUNT <= amount <= MAX_AMOUNT):
        return (
            None,
            f"Amount must be between ₹{MIN_AMOUNT:.2f} and ₹{MAX_AMOUNT:,.2f}",
        )

    amount = round(amount, 2)

    # Description validation
    if description is None:
        description = ""
    elif not isinstance(description, str):
        return None, "description must be a string"
    description = description.strip()
    if len(description) > MAX_DESCRIPTION_LENGTH:
        return (
            None,
            f"description exceeds maximum length of {MAX_DESCRIPTION_LENGTH} characters",
        )

    # Date validation
    if not isinstance(expense_date_raw, str):
        return None, "expense_date must be an ISO format string (YYYY-MM-DD)"
    try:
        parsed_date = date.fromisoformat(expense_date_raw.strip())
    except (ValueError, TypeError):
        return None, "Invalid expense_date format, expected YYYY-MM-DD"

    if not (MIN_DATE <= parsed_date <= MAX_DATE):
        return (
            None,
            f"expense_date must be between {MIN_DATE.isoformat()} and {MAX_DATE.isoformat()}",
        )

    return {
        "amount": amount,
        "category": category,
        "description": description,
        "expense_date": parsed_date,
    }, None


@api.get("/health")
@limiter.exempt
def health():
    """Health check probe used by ALB backend target group and frontend UI."""
    return jsonify({"status": "ok", "service": "expense-api"})


@api.get("/infrastructure")
@limiter.limit("10 per second; 60 per minute")
@require_auth
def get_infrastructure():
    """Returns basic service status without leaking internal cloud metadata."""
    return jsonify({
        "status": "operational",
        "service": "expense-api",
    })


@api.get("/expenses")
@limiter.limit("10 per second; 60 per minute")
@require_auth
def list_expenses():
    """Lists expenses up to MAX_EXPENSES_LIMIT to prevent resource exhaustion."""
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, amount, category, description, expense_date, created_at
                    FROM expenses
                    ORDER BY expense_date DESC, id DESC
                    LIMIT %s
                    """,
                    (MAX_EXPENSES_LIMIT,),
                )
                rows = cur.fetchall()
    except Exception as e:
        logger.error("Failed to query expenses from database: %s", str(e))
        return jsonify({"error": "Failed to retrieve expenses"}), 500

    for row in rows:
        row["amount"] = float(row["amount"])
        row["expense_date"] = (
            row["expense_date"].isoformat()
            if hasattr(row["expense_date"], "isoformat")
            else str(row["expense_date"])
        )
        row["created_at"] = (
            row["created_at"].isoformat()
            if hasattr(row["created_at"], "isoformat")
            else str(row["created_at"])
        )

    return jsonify(rows)


@api.post("/expenses")
@limiter.limit("2 per second; 20 per minute")
@require_auth
def create_expense():
    """Creates a validated expense record with strict input validation."""
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 415

    data = request.get_json(silent=True)
    if data is None:
        return jsonify({"error": "Invalid or malformed JSON payload"}), 400

    validated, error_msg = validate_expense_input(data)
    if error_msg:
        return jsonify({"error": error_msg}), 400

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO expenses (amount, category, description, expense_date)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, amount, category, description, expense_date, created_at
                    """,
                    (
                        validated["amount"],
                        validated["category"],
                        validated["description"],
                        validated["expense_date"],
                    ),
                )
                row = cur.fetchone()
            conn.commit()
    except Exception as e:
        logger.error("Failed to insert expense into database: %s", str(e))
        return jsonify({"error": "Failed to save expense"}), 500

    row["amount"] = float(row["amount"])
    row["expense_date"] = (
        row["expense_date"].isoformat()
        if hasattr(row["expense_date"], "isoformat")
        else str(row["expense_date"])
    )
    row["created_at"] = (
        row["created_at"].isoformat()
        if hasattr(row["created_at"], "isoformat")
        else str(row["created_at"])
    )

    return jsonify(row), 201


@api.delete("/expenses/<int:expense_id>")
@limiter.limit("2 per second; 15 per minute")
@require_auth
def delete_expense(expense_id):
    """
    Deletes an expense record by ID.
    Residual risk: In an anonymous public portfolio demo, any visitor can delete
    a visible expense. Strong rate limiting (2/sec, 15/min) and ID bounds prevent
    automated scraping or bulk deletion loops.
    """
    if expense_id < 1 or expense_id > MAX_EXPENSE_ID:
        return jsonify({"error": "Invalid expense ID"}), 400

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM expenses WHERE id = %s RETURNING id",
                    (expense_id,),
                )
                deleted = cur.fetchone()
            conn.commit()
    except Exception as e:
        logger.error("Failed to delete expense from database: %s", str(e))
        return jsonify({"error": "Failed to delete expense"}), 500

    if not deleted:
        return jsonify({"error": "Expense not found"}), 404

    return jsonify({"message": "Expense deleted successfully"})


@api.post("/reports")
@limiter.limit("10 per second; 30 per minute")
def generate_report():
    """
    Invokes Lambda expense-tracker-lambda synchronously server-side.
    Safely unwraps Lambda response, returning presigned S3 report details.
    """
    lambda_function_name = os.getenv("EXPENSE_LAMBDA_NAME", "expense-tracker-lambda")
    try:
        client = get_lambda_client()
        response = client.invoke(
            FunctionName=lambda_function_name,
            InvocationType="RequestResponse",
            Payload=b"{}",
        )
    except Exception as e:
        logger.error("Failed to invoke report Lambda: %s", str(e))
        return jsonify({"error": "Report generation service unavailable"}), 500

    # Check for Lambda unhandled execution error
    if "FunctionError" in response:
        error_payload = response.get("Payload")
        error_msg = error_payload.read().decode("utf-8") if error_payload else "Unknown error"
        logger.error("Lambda execution returned FunctionError: %s", error_msg)
        return jsonify({"error": "Failed to generate report"}), 502

    try:
        payload_bytes = response["Payload"].read()
        payload = json.loads(payload_bytes.decode("utf-8"))
    except Exception as e:
        logger.error("Failed to parse Lambda response payload: %s", str(e))
        return jsonify({"error": "Failed to generate report"}), 502

    # Lambda returns an API-Gateway proxy dict: {"statusCode": 200, "headers": ..., "body": "{\"status\":\"success\", ...}"}
    if isinstance(payload, dict):
        status_code = payload.get("statusCode", 200)
        body = payload.get("body", payload)
        if isinstance(body, str):
            try:
                body = json.loads(body)
            except Exception:
                pass
        if isinstance(body, dict) and body.get("status") == "error":
            logger.error("Lambda report error: %s", body.get("message"))
            return jsonify({"error": "Failed to generate report"}), 502
        return jsonify(body), status_code

    return jsonify(payload), 200
