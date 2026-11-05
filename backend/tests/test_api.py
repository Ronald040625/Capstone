import os
from io import BytesIO
from pathlib import Path

TEST_DB = Path(__file__).resolve().parents[1] / "corestream-test.db"
if TEST_DB.exists():
    TEST_DB.unlink()
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{TEST_DB.as_posix()}"
os.environ["SECRET_KEY"] = "test-key"

from fastapi.testclient import TestClient
from openpyxl import load_workbook

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

        ticket_detail = client.get(
            "/mobile/tickets/t-auth/detail", headers=admin_headers
        )
        assert ticket_detail.status_code == 200
        ticket_sla = ticket_detail.json()["ticket"]["sla"]
        assert ticket_sla["target_minutes"] == 480
        assert ticket_sla["is_overdue"] is True
        assert ticket_sla["is_escalated"] is True

        admin_notifications = client.get(
            "/notifications/", headers=admin_headers
        ).json()
        sla_notifications = [
            item for item in admin_notifications if item["type"] == "SLA_ESCALATION"
        ]
        assert len(sla_notifications) == 1
        assert sla_notifications[0]["ticket_id"] == "t-auth"

        reevaluate = client.post("/sla/evaluate", headers=admin_headers)
        assert reevaluate.status_code == 200
        assert reevaluate.json()["escalated_count"] == 0

        incidents = client.get("/incidents/", headers=admin_headers).json()
        assert any(item["id"] == "i-lang" for item in incidents)

        diego = login(client, "u-diego")
        diego_headers = headers(diego)
        assert client.post("/sla/evaluate", headers=diego_headers).status_code == 403
        general = client.get("/incidents/", headers=diego_headers).json()
        mine = client.get("/incidents/my-incidents", headers=diego_headers).json()
        assert len(general) == 3
        assert [item["id"] for item in mine] == ["i-login"]
        incident_detail = client.get(
            "/incidents/i-login", headers=diego_headers
        ).json()
        comment_dates = [item["created_at"] for item in incident_detail["comments"]]
        assert comment_dates == sorted(comment_dates)

        assigned = client.post(
            "/incidents/i-lang/assign",
            headers=admin_headers,
            json={"assignee_id": "u-diego"},
        )
        assert assigned.status_code == 200

        device = client.post(
            "/devices/",
            headers=diego_headers,
            json={"fcm_token": "fcm-diego-test", "platform": "android"},
        )
        assert device.status_code == 200
        assert device.json()["active"] is True
        comment = client.post(
            "/incidents/i-lang/comments",
            headers=diego_headers,
            json={"content": "Comentario persistente de prueba."},
        )
        assert comment.status_code == 200

        review = client.post("/incidents/i-lang/review", headers=diego_headers)
        assert review.status_code == 200
        denied_resolve = client.post(
            "/incidents/i-lang/resolve", headers=diego_headers
        )
        assert denied_resolve.status_code == 403
        assert client.post(
            "/incidents/i-lang/resolve", headers=admin_headers
        ).status_code == 200
        assert client.post(
            "/incidents/i-lang/close", headers=admin_headers
        ).status_code == 200
        closed_comment = client.post(
            "/incidents/i-lang/comments",
            headers=diego_headers,
            json={"content": "Este comentario no debe guardarse."},
        )
        assert closed_comment.status_code == 409
        assert client.post(
            "/incidents/i-lang/reopen", headers=admin_headers
        ).status_code == 200
        detail = client.get("/incidents/i-lang", headers=diego_headers).json()
        assert detail["status"] == "REOPENED"
        assert detail["comments"][-1]["content"] == "Comentario persistente de prueba."

        workload = client.get("/mobile/team/workload", headers=admin_headers)
        assert workload.status_code == 200
        assert len(workload.json()) == 4
        assert all(member["user"]["is_active"] for member in workload.json())
        full_workload = client.get(
            "/mobile/team/workload?include_inactive=true", headers=admin_headers
        )
        assert len(full_workload.json()) == 5
        assert any(
            member["user"]["is_active"] is False for member in full_workload.json()
        )
        denied = client.get("/mobile/team/workload", headers=diego_headers)
        assert denied.status_code == 403

        projects_pdf = client.get(
            "/reports/projects?format=pdf", headers=admin_headers
        )
        assert projects_pdf.status_code == 200
        assert projects_pdf.content.startswith(b"%PDF")
        assert projects_pdf.headers["content-type"] == "application/pdf"

        project_excel = client.get(
            "/reports/projects?format=xlsx&project_id=p-mobile",
            headers=admin_headers,
        )
        assert project_excel.status_code == 200
        workbook = load_workbook(BytesIO(project_excel.content), read_only=True)
        project_rows = list(workbook["Reporte"].values)
        assert project_rows[1][1] == "Aplicación Mobile"
        assert [row[0] for row in project_rows[5:]] == ["Aplicación Mobile"]

        team_excel = client.get(
            "/reports/team?format=xlsx&include_inactive=true",
            headers=admin_headers,
        )
        assert team_excel.status_code == 200
        workbook = load_workbook(BytesIO(team_excel.content), read_only=True)
        team_rows = list(workbook["Reporte"].values)
        assert team_rows[1][1] == "Incluye inactivos"
        assert "Paula Soto" in [row[0] for row in team_rows[5:]]

        denied_report = client.get(
            "/reports/projects?format=pdf", headers=diego_headers
        )
        assert denied_report.status_code == 403
        invalid_report = client.get(
            "/reports/projects?format=csv", headers=admin_headers
        )
        assert invalid_report.status_code == 422

        logout = client.post(
            "/auth/logout",
            headers=diego_headers,
            json={
                "refresh_token": diego["refresh_token"],
                "fcm_token": "fcm-diego-test",
            },
        )
        assert logout.status_code == 200
        assert logout.json()["device_deactivated"] is True
        refresh = client.post(
            "/auth/refresh", json={"refresh_token": diego["refresh_token"]}
        )
        assert refresh.status_code == 401
        assert client.get("/auth/me", headers=diego_headers).status_code == 401
