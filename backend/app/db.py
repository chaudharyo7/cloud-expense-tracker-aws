import psycopg
from psycopg.rows import dict_row

from .config import get_database_url


def get_connection():
    return psycopg.connect(get_database_url(), row_factory=dict_row)


def init_db():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS expenses (
                    id SERIAL PRIMARY KEY,
                    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
                    category VARCHAR(50) NOT NULL,
                    description TEXT,
                    expense_date DATE NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
        conn.commit()
