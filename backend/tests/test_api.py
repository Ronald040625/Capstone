import os
from pathlib import Path

TEST_DB = Path(__file__).resolve().parents[1] / "corestream-test.db"
if TEST_DB.exists():
    TEST_DB.unlink()
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{TEST_DB.as_posix()}"
os.environ["SECRET_KEY"] = "test-key"

from fastapi.testclient import TestClient

from app.main import app


def login(client: TestClient, user_id: str) -> dict:
    response = client.post("/auth/demo-login", json={"user_id": user_id})
    assert response.status_code == 200
    return response.json()


def headers(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def test_database_and_main_flows():
    with TestClient(app) as client:
        health = client.get("/health")
        assert health.json() == {"status": "ok", "database": "connected"}

        users = client.get("/users/").json()
        assert len(users) == 4

        admin = login(client, "u-admin")
        admin_headers = headers(admin)
        dashboard = client.get("/mobile/dashboard", headers=admin_headers)
        assert dashboard.status_code == 200
        assert dashboard.json()["stats"]["applications"] == 3

        incidents = client.get("/incidents/", headers=admin_headers).json()
        assert any(item["id"] == "i-lang" for item in incidents)

        assigned = client.post(
            "/incidents/i-lang/assign",
            headers=admin_headers,
            json={"assignee_id": "u-diego"},
        )
        assert assigned.status_code == 200

        diego = login(client, "u-diego")
        diego_headers = headers(diego)
        comment = client.post(
            "/incidents/i-lang/comments",
            headers=diego_headers,
            json={"content": "Comentario persistente de prueba."},
        )
        assert comment.status_code == 200

        review = client.post("/incidents/i-lang/review", headers=diego_headers)
        assert review.status_code == 200
        detail = client.get("/incidents/i-lang", headers=diego_headers).json()
        assert detail["status"] == "UNDER_REVIEW"
        assert detail["comments"][-1]["content"] == "Comentario persistente de prueba."

        workload = client.get("/mobile/team/workload", headers=admin_headers)
        assert workload.status_code == 200
        assert len(workload.json()) == 4
        denied = client.get("/mobile/team/workload", headers=diego_headers)
        assert denied.status_code == 403

        logout = client.post(
            "/auth/logout",
            headers=diego_headers,
            json={"refresh_token": diego["refresh_token"]},
        )
        assert logout.status_code == 200
        refresh = client.post(
            "/auth/refresh", json={"refresh_token": diego["refresh_token"]}
        )
        assert refresh.status_code == 401
