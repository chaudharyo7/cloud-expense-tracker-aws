import json
import os
import urllib.parse

from dotenv import load_dotenv

load_dotenv()

_CACHED_DATABASE_URL = None


def get_database_url():
    """
    Returns the database connection URL.
    In production (when DB_SECRET_ARN is provided):
      Retrieves the database credentials from AWS Secrets Manager using boto3,
      constructs the connection string, and caches it in application memory.
    In local development:
      Falls back to DATABASE_URL from environment or local default.
    """
    global _CACHED_DATABASE_URL
    if _CACHED_DATABASE_URL:
        return _CACHED_DATABASE_URL

    secret_arn = os.getenv("DB_SECRET_ARN")
    if secret_arn:
        import boto3
        region = os.getenv("AWS_REGION", "ap-south-1")
        sm = boto3.client("secretsmanager", region_name=region)
        resp = sm.get_secret_value(SecretId=secret_arn)
        secret_dict = json.loads(resp["SecretString"])

        password = urllib.parse.quote_plus(secret_dict["password"])
        user = os.getenv("DB_USER") or secret_dict.get("username") or "expense_user"
        host = os.getenv("DB_HOST") or secret_dict.get("host") or "localhost"
        port = os.getenv("DB_PORT") or str(secret_dict.get("port", "5432"))
        dbname = os.getenv("DB_NAME") or secret_dict.get("dbname") or "expense_db"

        _CACHED_DATABASE_URL = f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
    else:
        _CACHED_DATABASE_URL = os.getenv(
            "DATABASE_URL",
            "postgresql://expense_user:expense_password@localhost:5432/expense_db",
        )

    return _CACHED_DATABASE_URL


def is_auth_enabled() -> bool:
    """
    Returns True if JWT authentication is enabled, False otherwise.
    In the public portfolio application without a frontend login UI, defaults to False
    so public visitors can use the expense tracker without authentication.
    To enforce JWT verification, set AUTH_ENABLED=true in the environment.
    """
    val = os.getenv("AUTH_ENABLED", "false")
    return val.strip().lower() in ("true", "1", "yes", "on")


def get_cognito_region() -> str:
    """Returns the AWS region for Cognito User Pool (defaults to AWS_REGION or ap-south-1)."""
    return os.getenv("COGNITO_REGION") or os.getenv("AWS_REGION", "ap-south-1")


def get_cognito_user_pool_id() -> str:
    """Returns the Cognito User Pool ID."""
    return os.getenv("COGNITO_USER_POOL_ID", "").strip()


def get_cognito_client_id() -> str:
    """Returns the Cognito User Pool Client ID (app client ID / audience)."""
    return (
        os.getenv("COGNITO_APP_CLIENT_ID")
        or os.getenv("COGNITO_CLIENT_ID", "")
    ).strip()

