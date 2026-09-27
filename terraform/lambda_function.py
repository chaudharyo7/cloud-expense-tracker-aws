import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3
import pg8000.native

# In-memory cache for the database password to avoid redundant Secrets Manager calls on warm starts
_CACHED_DB_PASSWORD = None


def get_db_password(region, secret_id):
    global _CACHED_DB_PASSWORD
    if _CACHED_DB_PASSWORD:
        return _CACHED_DB_PASSWORD

    sm = boto3.client("secretsmanager", region_name=region)
    resp = sm.get_secret_value(SecretId=secret_id)
    secret_dict = json.loads(resp["SecretString"])
    _CACHED_DB_PASSWORD = secret_dict["password"]
    return _CACHED_DB_PASSWORD


def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


def lambda_handler(event, context):
    cors_headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
    }

    # Handle HTTP OPTIONS preflight
    http_method = (
        event.get("requestContext", {}).get("http", {}).get("method", "")
    )
    if http_method == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": cors_headers,
            "body": ""
        }

    try:
        region = os.environ.get("AWS_REGION", "ap-south-1")
        db_host = os.environ["DB_HOST"]
        db_port = int(os.environ.get("DB_PORT", "5432"))
        db_name = os.environ["DB_NAME"]
        db_user = os.environ["DB_USER"]
        s3_bucket = os.environ["S3_BUCKET"]
        db_secret_arn = os.environ["DB_SECRET_ARN"]

        db_password = get_db_password(region, db_secret_arn)

        # 1. Connect to PostgreSQL RDS
        conn = pg8000.native.Connection(
            user=db_user,
            password=db_password,
            host=db_host,
            port=db_port,
            database=db_name,
            timeout=10,
        )

        try:
            # 2. Query summary statistics
            summary_query = """
                SELECT
                    COALESCE(COUNT(*), 0) AS total_count,
                    COALESCE(SUM(amount), 0) AS total_amount
                FROM expenses
            """
            summary_row = conn.run(summary_query)[0]
            total_count = int(summary_row[0])
            total_amount = float(summary_row[1])

            # 3. Query category breakdown
            category_query = """
                SELECT
                    category,
                    COUNT(*) AS count,
                    SUM(amount) AS total
                FROM expenses
                GROUP BY category
                ORDER BY total DESC
            """
            category_rows = conn.run(category_query)
            category_breakdown = [
                {
                    "category": r[0],
                    "count": int(r[1]),
                    "total": float(r[2])
                }
                for r in category_rows
            ]

            # 4. Query itemized expenses
            expenses_query = """
                SELECT
                    id,
                    amount,
                    category,
                    description,
                    expense_date,
                    created_at
                FROM expenses
                ORDER BY expense_date DESC, id DESC
            """
            expense_rows = conn.run(expenses_query)
            expenses = [
                {
                    "id": r[0],
                    "amount": float(r[1]),
                    "category": r[2],
                    "description": r[3] or "",
                    "expense_date": str(r[4]),
                    "created_at": r[5].isoformat() if r[5] else "",
                }
                for r in expense_rows
            ]
        finally:
            conn.close()

        # 5. Build structured report document
        generated_at = datetime.now(timezone.utc).isoformat()
        report_data = {
            "title": "Cloud Expense Tracker - Expense Report",
            "generated_at": generated_at,
            "currency": "INR",
            "summary": {
                "total_count": total_count,
                "total_amount": total_amount,
                "categories": category_breakdown,
            },
            "expenses": expenses,
        }

        # 6. Upload report to S3
        timestamp_slug = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        report_key = f"reports/expense-report-{timestamp_slug}.json"
        report_json = json.dumps(report_data, indent=2, default=decimal_default)

        s3 = boto3.client("s3", region_name=region)
        s3.put_object(
            Bucket=s3_bucket,
            Key=report_key,
            Body=report_json,
            ContentType="application/json",
        )

        # 7. Generate Pre-signed GET URL (valid for 1 hour)
        presigned_url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": s3_bucket, "Key": report_key},
            ExpiresIn=3600,
        )

        # 8. Return response
        return {
            "statusCode": 200,
            "headers": cors_headers,
            "body": json.dumps({
                "status": "success",
                "message": "Report generated successfully",
                "report_url": presigned_url,
                "report_key": report_key,
                "generated_at": generated_at,
                "expense_count": total_count,
                "total_amount": total_amount,
            }),
        }

    except Exception as e:
        print(f"Error generating report: {e}")
        return {
            "statusCode": 500,
            "headers": cors_headers,
            "body": json.dumps({
                "status": "error",
                "message": str(e)
            }),
        }