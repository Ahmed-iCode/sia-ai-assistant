from fastapi.testclient import TestClient
from app.main import app
from app.core.config import Settings


def test_health_check_endpoint():
    """Verify GET /health returns 200 with status ok without auth."""
    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_cors_headers_with_origin():
    """Verify CORS headers respond to allowed origins with credentials."""
    client = TestClient(app)
    response = client.get("/health", headers={"Origin": "https://sia-app.pages.dev"})
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == "https://sia-app.pages.dev"
    assert response.headers.get("access-control-allow-credentials") == "true"


def test_settings_merged_cors_origins():
    """Verify Settings properly parses comma-separated CORS_ORIGINS and merges them."""
    s = Settings(
        BACKEND_CORS_ORIGINS=["http://localhost:3000"],
        CORS_ORIGINS="https://sia-app.pages.dev, https://sia.custom.com",
    )
    merged = s.merged_cors_origins
    assert "http://localhost:3000" in merged
    assert "https://sia-app.pages.dev" in merged
    assert "https://sia.custom.com" in merged
