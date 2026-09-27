import os

from flask import Flask
from flask_cors import CORS
from werkzeug.middleware.proxy_fix import ProxyFix

from .db import init_db
from .limiter import limiter
from .routes import api


def create_app():
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 16 * 1024  # 16 KB max request body
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)
    limiter.init_app(app)

    # Environment-aware CORS configuration
    allowed_origins = [
        o.strip()
        for o in os.getenv(
            "CORS_ALLOWED_ORIGINS",
            "https://projects.yamandeep.in,http://localhost,http://localhost:80,http://127.0.0.1",
        ).split(",")
        if o.strip()
    ]
    CORS(app, origins=allowed_origins)

    # HTTP Security Headers
    @app.after_request
    def set_security_headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = (
            "geolocation=(), camera=(), microphone=()"
        )
        response.headers["Strict-Transport-Security"] = (
            "max-age=31536000; includeSubDomains"
        )
        response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
        response.headers["Cache-Control"] = "no-store, max-age=0"
        return response

    # Standard JSON error handlers for safe error handling
    @app.errorhandler(400)
    def bad_request(e):
        return {"error": getattr(e, "description", "Bad request")}, 400

    @app.errorhandler(404)
    def not_found(e):
        return {"error": "Resource not found"}, 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return {"error": "Method not allowed"}, 405

    @app.errorhandler(413)
    def payload_too_large(e):
        return {"error": "Payload exceeds maximum allowed size"}, 413

    @app.errorhandler(415)
    def unsupported_media_type(e):
        return {"error": "Unsupported Media Type: expected application/json"}, 415

    @app.errorhandler(429)
    def ratelimit_exceeded(e):
        return {"error": "Too many requests. Please slow down."}, 429

    @app.errorhandler(500)
    def internal_error(e):
        return {"error": "Internal server error"}, 500

    init_db()
    app.register_blueprint(api, url_prefix="/api")

    return app


app = create_app()


if __name__ == "__main__":
    debug = os.getenv("FLASK_DEBUG", "false").lower() in ("true", "1", "yes")
    app.run(host="0.0.0.0", port=8000, debug=debug)
