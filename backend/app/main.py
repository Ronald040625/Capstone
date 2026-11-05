import asyncio
import os
import uuid
from contextlib import asynccontextmanager, suppress
from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Response, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from .database import SessionLocal, create_tables, engine, get_db
from .models import (
    Epic,
    Incident,
    IncidentComment,
    Notification,
    Project,
    PushDevice,
    SessionToken,
    SlaRecord,
    Subtask,
    Ticket,
    TicketEvent,
    User,
    utcnow,
)
from .security import (
    create_access_token,
    create_refresh_token,
    hash_refresh_token,
    read_access_claims,
    verify_password,
)
from .reports import build_excel_report, build_pdf_report
from .seed import seed_database


class LoginBody(BaseModel):
    email: str
    password: str


class DemoLoginBody(BaseModel):
    user_id: str


class LogoutBody(BaseModel):
    refresh_token: str | None = None
    fcm_token: str | None = None


class RefreshBody(BaseModel):
    refresh_token: str


class DeviceBody(BaseModel):
    fcm_token: str
    platform: str


class AssignBody(BaseModel):
    assignee_id: str
    comment: str | None = None


class CommentBody(BaseModel):
    content: str


class CompleteBody(BaseModel):
    pr_link: str


class QuestionBody(BaseModel):
    question_text: str


class ResolutionBody(BaseModel):
    resolution_text: str


class RedirectBody(BaseModel):
    to_user_id: str
    reason: str


class SubtaskBody(BaseModel):
    is_completed: bool


class CreateTicketBody(BaseModel):
    epic_id: str
    title: str
    priority: str = "MEDIUM"
    assignee_id: str | None = None


class MarkReadBody(BaseModel):
    notification_ids: list[str]


@asynccontextmanager
async def lifespan(_: FastAPI):
    await create_tables()
    async with SessionLocal() as db:
        await seed_database(db)
        await _evaluate_slas(db)
    sla_task = asyncio.create_task(_sla_monitor())
    try:
        yield
    finally:
        sla_task.cancel()
        with suppress(asyncio.CancelledError):
            await sla_task
        await engine.dispose()


app = FastAPI(title="CoreStream MVP API", version="1.0.0", lifespan=lifespan)
origins = [value.strip() for value in os.getenv("CORS_ORIGINS", "").split(",") if value.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _id() -> str:
    return str(uuid.uuid4())


def _iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


SLA_TARGET_MINUTES = {
    "TICKET": {"URGENT": 240, "HIGH": 480, "MEDIUM": 1440, "LOW": 2880},
    "INCIDENT": {"CRITICAL": 120, "HIGH": 480, "MEDIUM": 1440, "LOW": 2880},
}


def _sla_target(item_type: str, policy_key: str) -> int:
    return SLA_TARGET_MINUTES[item_type].get(policy_key, 1440)


async def _ensure_sla_records(db: AsyncSession) -> None:
    existing = {
        record.id
        for record in (await db.scalars(select(SlaRecord))).all()
    }
    now = datetime.now(timezone.utc)
    tickets = (
        await db.scalars(select(Ticket).options(selectinload(Ticket.events)))
    ).all()
    incidents = (await db.scalars(select(Incident))).all()
    created = False

    for ticket in tickets:
        record_id = f"TICKET:{ticket.id}"
        if record_id in existing:
            continue
        minutes = _sla_target("TICKET", ticket.priority)
        started_at = min(
            (_utc(event.created_at) for event in ticket.events),
            default=now,
        )
        db.add(
            SlaRecord(
                id=record_id,
                item_type="TICKET",
                item_id=ticket.id,
                policy_key=ticket.priority,
                target_minutes=minutes,
                started_at=started_at,
                due_at=started_at + timedelta(minutes=minutes),
            )
        )
        created = True

    for incident in incidents:
        record_id = f"INCIDENT:{incident.id}"
        if record_id in existing:
            continue
        minutes = _sla_target("INCIDENT", incident.severity)
        started_at = _utc(incident.created_at)
        db.add(
            SlaRecord(
                id=record_id,
                item_type="INCIDENT",
                item_id=incident.id,
                policy_key=incident.severity,
                target_minutes=minutes,
                started_at=started_at,
                due_at=started_at + timedelta(minutes=minutes),
            )
        )
        created = True

    if created:
        await db.commit()


def _sla_json(record: SlaRecord | None, active: bool) -> dict | None:
    if not record:
        return None
    now = datetime.now(timezone.utc)
    remaining = int((_utc(record.due_at) - now).total_seconds())
    return {
        "policy_key": record.policy_key,
        "target_minutes": record.target_minutes,
        "active": active,
        "started_at": _iso(record.started_at),
        "due_at": _iso(record.due_at),
        "remaining_seconds": remaining,
        "is_overdue": active and remaining < 0,
        "is_escalated": record.escalated_at is not None,
        "escalated_at": _iso(record.escalated_at),
    }


async def _sla_map(
    db: AsyncSession, item_type: str, item_ids: list[str]
) -> dict[str, SlaRecord]:
    await _ensure_sla_records(db)
    if not item_ids:
        return {}
    records = (
        await db.scalars(
            select(SlaRecord).where(
                SlaRecord.item_type == item_type,
                SlaRecord.item_id.in_(item_ids),
            )
        )
    ).all()
    return {record.item_id: record for record in records}


async def _evaluate_slas(db: AsyncSession) -> int:
    await _ensure_sla_records(db)
    now = datetime.now(timezone.utc)
    records = (
        await db.scalars(
            select(SlaRecord).where(
                SlaRecord.escalated_at.is_(None),
                SlaRecord.due_at <= now,
            )
        )
    ).all()
    if not records:
        return 0
    tickets = {ticket.id: ticket for ticket in (await db.scalars(select(Ticket))).all()}
    incidents = {
        incident.id: incident for incident in (await db.scalars(select(Incident))).all()
    }
    leaders = (
        await db.scalars(
            select(User).where(
                User.is_active.is_(True),
                User.role.in_(["ADMIN", "GROUP_LEADER"]),
            )
        )
    ).all()
    escalated = 0
    for record in records:
        if record.item_type == "TICKET":
            item = tickets.get(record.item_id)
            if not item or item.status == "DONE":
                continue
            label = f"ticket #{item.number}"
            kwargs = {"ticket_id": item.id}
        else:
            item = incidents.get(record.item_id)
            if not item or item.status in {"RESOLVED", "CLOSED"}:
                continue
            label = f"incidencia INC-{item.number}"
            kwargs = {"incident_id": item.id}
        record.escalated_at = now
        for leader in leaders:
            await _notify(
                db,
                leader.id,
                "SLA_ESCALATION",
                f"SLA vencido: {label} requiere atención.",
                **kwargs,
            )
        escalated += 1
    await db.commit()
    return escalated


async def _sla_monitor() -> None:
    while True:
        try:
            async with SessionLocal() as db:
                await _evaluate_slas(db)
        except Exception:
            pass
        await asyncio.sleep(60)


def user_json(user: User) -> dict:
    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "role": user.role,
        "specialty": user.specialty,
        "is_active": user.is_active,
    }


async def current_user(
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Sesión no válida.")
    claims = read_access_claims(authorization.removeprefix("Bearer ").strip())
    if not claims:
        raise HTTPException(401, "Sesión no válida.")
    user_id, session_id = claims
    session = await db.get(SessionToken, session_id)
    if not session or session.revoked or session.user_id != user_id:
        raise HTTPException(401, "Sesión no válida.")
    user = await db.get(User, user_id) if user_id else None
    if not user or not user.is_active:
        raise HTTPException(401, "Sesión no válida.")
    return user


async def _create_session(db: AsyncSession, user: User) -> dict:
    refresh = create_refresh_token()
    session_id = hash_refresh_token(refresh)
    db.add(SessionToken(token=session_id, user_id=user.id))
    await db.commit()
    return {
        "access_token": create_access_token(user.id, session_id),
        "refresh_token": refresh,
        "token_type": "bearer",
        "user": user_json(user),
    }


def _require_lead(user: User) -> None:
    if user.role not in {"ADMIN", "GROUP_LEADER"}:
        raise HTTPException(403, "No tienes permisos para realizar esta acción.")


async def _users_by_id(db: AsyncSession) -> dict[str, User]:
    users = (await db.scalars(select(User))).all()
    return {user.id: user for user in users}


async def _project_report_data(db: AsyncSession, project_id: str | None) -> tuple[str, list[list[object]]]:
    query = select(Project).options(selectinload(Project.epics).selectinload(Epic.tickets))
    if project_id:
        query = query.where(Project.id == project_id)
    projects = (await db.scalars(query.order_by(Project.name))).all()
    if project_id and not projects:
        raise HTTPException(404, "Proyecto no encontrado.")
    now = datetime.now(timezone.utc)
    rows = []
    for project in projects:
        tickets = [ticket for epic in project.epics for ticket in epic.tickets]
        done = sum(ticket.status == "DONE" for ticket in tickets)
        overdue = sum(
            ticket.status != "DONE"
            and ticket.due_date is not None
            and _utc(ticket.due_date) < now
            for ticket in tickets
        )
        rows.append([
            project.name,
            len(project.epics),
            len(tickets),
            done,
            len(tickets) - done,
            overdue,
        ])
    scope = projects[0].name if project_id else "Todos los proyectos"
    return scope, rows


async def _team_workload_data(db: AsyncSession, include_inactive: bool) -> list[dict]:
    users_query = select(User).order_by(User.full_name)
    if not include_inactive:
        users_query = users_query.where(User.is_active.is_(True))
    users = (await db.scalars(users_query)).all()
    tickets = (await db.scalars(select(Ticket))).all()
    incidents = (await db.scalars(select(Incident))).all()
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    return [
        {
            "user": user_json(member),
            "active_tickets": sum(ticket.assignee_id == member.id and ticket.status != "DONE" for ticket in tickets),
            "in_progress": sum(ticket.assignee_id == member.id and ticket.status == "IN_PROGRESS" for ticket in tickets),
            "blocked": sum(ticket.assignee_id == member.id and ticket.status == "BLOCKED" for ticket in tickets),
            "done_last_7d": sum(
                ticket.assignee_id == member.id
                and ticket.status == "DONE"
                and ticket.completed_at is not None
                and _utc(ticket.completed_at) >= week_ago
                for ticket in tickets
            ),
            "open_incidents": sum(
                incident.assignee_id == member.id and incident.status not in {"RESOLVED", "CLOSED"}
                for incident in incidents
            ),
        }
        for member in users
    ]


def _report_response(
    report_format: str,
    filename: str,
    title: str,
    scope: str,
    headers: list[str],
    rows: list[list[object]],
) -> Response:
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    if report_format == "pdf":
        content = build_pdf_report(title, scope, generated, headers, rows)
        media_type = "application/pdf"
    else:
        content = build_excel_report(title, scope, generated, headers, rows)
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    return Response(
        content=content,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}.{report_format}"'},
    )


def _ticket_summary(ticket: Ticket) -> dict:
    return {
        "id": ticket.id,
        "number": ticket.number,
        "title": ticket.title,
        "description": ticket.description,
        "status": ticket.status,
        "priority": ticket.priority,
        "assignee_id": ticket.assignee_id,
        "due_date": _iso(ticket.due_date),
        "subtasks_done": sum(1 for subtask in ticket.subtasks if subtask.is_completed),
        "subtasks_total": len(ticket.subtasks),
    }


def _incident_json(
    incident: Incident,
    users: dict[str, User],
    sla: SlaRecord | None = None,
) -> dict:
    comments = sorted(incident.comments, key=lambda item: item.created_at)
    return {
        "id": incident.id,
        "number": incident.number,
        "application_id": incident.project_id,
        "title": incident.title,
        "description": incident.description,
        "category": incident.category,
        "severity": incident.severity,
        "status": incident.status,
        "reporter_id": incident.reporter_id,
        "assignee_id": incident.assignee_id,
        "created_at": _iso(incident.created_at),
        "sla": _sla_json(sla, incident.status not in {"RESOLVED", "CLOSED"}),
        "comments": [
            {
                "id": comment.id,
                "user_id": comment.user_id,
                "content": comment.content,
                "created_at": _iso(comment.created_at),
                "user": user_json(users[comment.user_id]),
            }
            for comment in comments
        ],
    }


async def _incident_or_404(db: AsyncSession, incident_id: str) -> Incident:
    result = await db.scalar(
        select(Incident)
        .where(Incident.id == incident_id)
        .options(selectinload(Incident.comments))
    )
    if not result:
        raise HTTPException(404, "Incidencia no encontrada.")
    return result


async def _ticket_or_404(db: AsyncSession, ticket_id: str) -> Ticket:
    result = await db.scalar(
        select(Ticket)
        .where(Ticket.id == ticket_id)
        .options(
            selectinload(Ticket.epic).selectinload(Epic.project),
            selectinload(Ticket.subtasks),
            selectinload(Ticket.events),
        )
    )
    if not result:
        raise HTTPException(404, "Ticket no encontrado.")
    return result


def _permissions(ticket: Ticket, user: User) -> dict:
    lead = user.role in {"ADMIN", "GROUP_LEADER"}
    mine = ticket.assignee_id == user.id
    return {
        "can_assign": lead and ticket.status != "DONE",
        "can_start": mine and ticket.status in {"TODO", "REDIRECTED"},
        "can_complete": mine and ticket.status == "IN_PROGRESS",
        "can_question": mine and ticket.status == "IN_PROGRESS",
        "can_resolve_question": (mine or lead) and ticket.status == "BLOCKED",
        "can_redirect": mine and ticket.status == "IN_PROGRESS",
        "can_edit_subtasks": (mine or lead) and ticket.status != "DONE",
        "can_edit": lead,
        "can_delete": user.role == "ADMIN",
    }


async def _add_ticket_event(db: AsyncSession, ticket: Ticket, user: User, event_type: str, text: str | None = None):
    db.add(
        TicketEvent(
            id=_id(),
            ticket_id=ticket.id,
            user_id=user.id,
            event_type=event_type,
            text=text,
        )
    )


async def _notify(
    db: AsyncSession,
    user_id: str | None,
    kind: str,
    message: str,
    ticket_id: str | None = None,
    incident_id: str | None = None,
):
    if user_id:
        db.add(
            Notification(
                id=_id(),
                user_id=user_id,
                type=kind,
                message=message,
                ticket_id=ticket_id,
                incident_id=incident_id,
            )
        )


@app.get("/health")
async def health():
    return {"status": "ok", "database": "connected"}


@app.get("/users/")
async def list_users(db: AsyncSession = Depends(get_db)):
    users = (await db.scalars(select(User).where(User.is_active.is_(True)).order_by(User.full_name))).all()
    return [user_json(user) for user in users]


@app.post("/auth/demo-login")
async def demo_login(body: DemoLoginBody, db: AsyncSession = Depends(get_db)):
    user = await db.get(User, body.user_id)
    if not user or not user.is_active:
        raise HTTPException(401, "Usuario no válido.")
    return await _create_session(db, user)


@app.post("/auth/login")
async def login(body: LoginBody, db: AsyncSession = Depends(get_db)):
    user = await db.scalar(select(User).where(User.email == body.email.lower().strip()))
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(401, "Correo o contraseña incorrectos.")
    return await _create_session(db, user)


@app.get("/auth/me")
async def auth_me(user: User = Depends(current_user)):
    return user_json(user)


@app.post("/auth/refresh")
async def refresh_session(body: RefreshBody, db: AsyncSession = Depends(get_db)):
    session_id = hash_refresh_token(body.refresh_token)
    token = await db.get(SessionToken, session_id)
    if not token or token.revoked:
        raise HTTPException(401, "La sesión ya no está vigente.")
    user = await db.get(User, token.user_id)
    if not user or not user.is_active:
        raise HTTPException(401, "La sesión ya no está vigente.")
    return {
        "access_token": create_access_token(user.id, session_id),
        "token_type": "bearer",
    }


@app.post("/auth/logout")
async def logout(
    body: LogoutBody,
    user: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
):
    changed = False
    if body.refresh_token:
        token = await db.get(SessionToken, hash_refresh_token(body.refresh_token))
        if token and token.user_id == user.id:
            token.revoked = True
            changed = True
    device_deactivated = False
    if body.fcm_token:
        device = await db.scalar(
            select(PushDevice).where(
                PushDevice.user_id == user.id,
                PushDevice.fcm_token == body.fcm_token,
            )
        )
        if device:
            device.is_active = False
            device_deactivated = True
            changed = True
    if changed:
        await db.commit()
    return {"ok": True, "device_deactivated": device_deactivated}


@app.get("/mobile/dashboard")
async def dashboard(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ticket_rows = (
        await db.scalars(
            select(Ticket).options(selectinload(Ticket.subtasks), selectinload(Ticket.epic))
        )
    ).all()
    incident_rows = (
        await db.scalars(select(Incident).options(selectinload(Incident.comments)))
    ).all()
    now = datetime.now(timezone.utc)

    if user.role == "DEVELOPER":
        mine = [ticket for ticket in ticket_rows if ticket.assignee_id == user.id]
        my_incidents = [
            incident
            for incident in incident_rows
            if incident.assignee_id == user.id and incident.status not in {"RESOLVED", "CLOSED"}
        ]
        return {
            "role": user.role,
            "stats": {
                "my_open": sum(ticket.status != "DONE" for ticket in mine),
                "in_progress": sum(ticket.status == "IN_PROGRESS" for ticket in mine),
                "done_last_7d": sum(
                    ticket.status == "DONE"
                    and ticket.completed_at is not None
                    and _utc(ticket.completed_at) >= now - timedelta(days=7)
                    for ticket in mine
                ),
                "my_open_incidents": len(my_incidents),
            },
            "my_tickets": [_ticket_summary(ticket) for ticket in mine if ticket.status != "DONE"],
            "my_incidents": [
                {
                    "id": incident.id,
                    "title": incident.title,
                    "status": incident.status,
                    "severity": incident.severity,
                    "created_at": _iso(incident.created_at),
                }
                for incident in my_incidents
            ],
        }

    projects = (
        await db.scalars(
            select(Project).options(selectinload(Project.epics).selectinload(Epic.tickets).selectinload(Ticket.subtasks))
        )
    ).all()
    project_summaries = []
    for project in projects:
        project_tickets = [ticket for epic in project.epics for ticket in epic.tickets]
        project_summaries.append(
            {
                "id": project.id,
                "name": project.name,
                "epics_count": len(project.epics),
                "tickets_total": len(project_tickets),
                "tickets_done": sum(ticket.status == "DONE" for ticket in project_tickets),
                "overdue": sum(
                    ticket.due_date is not None
                    and ticket.status != "DONE"
                    and _utc(ticket.due_date) < now
                    for ticket in project_tickets
                ),
            }
        )
    project_names = {project.id: project.name for project in projects}
    attention = [
        {
            "kind": "TICKET",
            "id": ticket.id,
            "title": ticket.title,
            "status": ticket.status,
            "due_date": _iso(ticket.due_date),
            "app_name": project_names.get(ticket.epic.project_id, ""),
        }
        for ticket in ticket_rows
        if ticket.status == "BLOCKED" or (
            ticket.due_date is not None and ticket.status != "DONE" and _utc(ticket.due_date) < now
        )
    ]
    attention += [
        {
            "kind": "INCIDENT",
            "id": incident.id,
            "title": incident.title,
            "status": incident.status,
            "severity": incident.severity,
            "app_name": project_names.get(incident.project_id, ""),
        }
        for incident in incident_rows
        if incident.severity == "CRITICAL" and incident.status not in {"RESOLVED", "CLOSED"}
    ]
    return {
        "role": user.role,
        "stats": {
            "applications": len(projects),
            "open_tickets": sum(ticket.status != "DONE" for ticket in ticket_rows),
            "blocked_tickets": sum(ticket.status == "BLOCKED" for ticket in ticket_rows),
            "overdue_tickets": sum(
                ticket.due_date is not None
                and ticket.status != "DONE"
                and _utc(ticket.due_date) < now
                for ticket in ticket_rows
            ),
        },
        "projects": project_summaries,
        "attention": attention,
    }


@app.get("/mobile/applications")
async def applications(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    projects = (
        await db.scalars(
            select(Project).options(selectinload(Project.epics).selectinload(Epic.tickets))
        )
    ).all()
    return [
        {
            "id": project.id,
            "name": project.name,
            "epics_count": len(project.epics),
            "tickets_total": sum(len(epic.tickets) for epic in project.epics),
            "tickets_done": sum(
                ticket.status == "DONE" for epic in project.epics for ticket in epic.tickets
            ),
            "overdue": 0,
        }
        for project in projects
    ]


@app.get("/mobile/applications/{project_id}/board")
async def board(project_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    project = await db.scalar(
        select(Project)
        .where(Project.id == project_id)
        .options(selectinload(Project.epics).selectinload(Epic.tickets).selectinload(Ticket.subtasks))
    )
    if not project:
        raise HTTPException(404, "Proyecto no encontrado.")
    return {
        "application": {"id": project.id, "name": project.name},
        "epics": [
            {
                "id": epic.id,
                "name": epic.name,
                "order_index": epic.order_index,
                "tickets": [_ticket_summary(ticket) for ticket in epic.tickets],
            }
            for epic in sorted(project.epics, key=lambda item: item.order_index)
        ],
    }


@app.get("/mobile/tickets/{ticket_id}/detail")
async def ticket_detail(ticket_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ticket = await _ticket_or_404(db, ticket_id)
    sla = (await _sla_map(db, "TICKET", [ticket.id])).get(ticket.id)
    assignee = await db.get(User, ticket.assignee_id) if ticket.assignee_id else None
    creator = await db.get(User, ticket.created_by_id)
    return {
        "ticket": {
            **_ticket_summary(ticket),
            "pr_link": ticket.pr_link,
            "time_spent_seconds": 0,
            "blocked_time_seconds": 0,
            "sla": _sla_json(sla, ticket.status != "DONE"),
        },
        "epic": {"id": ticket.epic.id, "name": ticket.epic.name},
        "application": {"id": ticket.epic.project.id, "name": ticket.epic.project.name},
        "assignee": user_json(assignee) if assignee else None,
        "created_by": user_json(creator) if creator else None,
        "subtasks": [
            {"id": subtask.id, "title": subtask.title, "is_completed": subtask.is_completed}
            for subtask in ticket.subtasks
        ],
        "events": [
            {
                "event_type": event.event_type,
                "created_at": _iso(event.created_at),
                "user": user_json(await db.get(User, event.user_id)),
                "payload": {"comment": event.text} if event.text else {},
            }
            for event in sorted(ticket.events, key=lambda item: item.created_at)
        ],
        "timer": {"time_spent_seconds": 0, "blocked_time_seconds": 0, "is_running": False},
        "permissions": _permissions(ticket, user),
    }


@app.get("/incidents/")
async def incidents(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.scalars(
            select(Incident).options(selectinload(Incident.comments)).order_by(Incident.created_at.desc())
        )
    ).all()
    users = await _users_by_id(db)
    slas = await _sla_map(db, "INCIDENT", [incident.id for incident in rows])
    return [_incident_json(incident, users, slas.get(incident.id)) for incident in rows]


@app.get("/incidents/my-incidents")
async def my_incidents(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.scalars(
            select(Incident)
            .where(Incident.assignee_id == user.id)
            .options(selectinload(Incident.comments))
            .order_by(Incident.created_at.desc())
        )
    ).all()
    users = await _users_by_id(db)
    slas = await _sla_map(db, "INCIDENT", [incident.id for incident in rows])
    return [_incident_json(incident, users, slas.get(incident.id)) for incident in rows]


@app.get("/incidents/{incident_id}")
async def incident_detail(incident_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    incident = await _incident_or_404(db, incident_id)
    sla = (await _sla_map(db, "INCIDENT", [incident.id])).get(incident.id)
    return _incident_json(incident, await _users_by_id(db), sla)


@app.post("/incidents/{incident_id}/assign")
async def assign_incident(incident_id: str, body: AssignBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    _require_lead(user)
    incident = await _incident_or_404(db, incident_id)
    if incident.status not in {"OPEN", "REOPENED"}:
        raise HTTPException(409, "La incidencia no se puede asignar en su estado actual.")
    assignee = await db.get(User, body.assignee_id)
    if not assignee or not assignee.is_active:
        raise HTTPException(404, "Usuario no encontrado.")
    incident.assignee_id = body.assignee_id
    incident.status = "IN_PROGRESS"
    await _notify(db, body.assignee_id, "INCIDENT_ASSIGNED", f"Se te asignó la incidencia INC-{incident.number}.", incident_id=incident.id)
    await db.commit()
    return {"ok": True}


@app.post("/incidents/{incident_id}/start")
async def start_incident(incident_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    incident = await _incident_or_404(db, incident_id)
    if incident.status not in {"OPEN", "REOPENED"}:
        raise HTTPException(409, "La incidencia no se puede iniciar en su estado actual.")
    incident.assignee_id = user.id
    incident.status = "IN_PROGRESS"
    await db.commit()
    return {"ok": True}


async def _change_incident_status(incident_id: str, target: str, allowed: set[str], user: User, db: AsyncSession, lead_only: bool = False):
    if lead_only:
        _require_lead(user)
    incident = await _incident_or_404(db, incident_id)
    if not lead_only and incident.assignee_id != user.id and user.role not in {"ADMIN", "GROUP_LEADER"}:
        raise HTTPException(403, "No tienes permisos para realizar esta acción.")
    if incident.status not in allowed:
        raise HTTPException(409, "La incidencia no se puede modificar en su estado actual.")
    incident.status = target
    await db.commit()
    return {"ok": True}


@app.post("/incidents/{incident_id}/review")
async def review_incident(incident_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    return await _change_incident_status(incident_id, "UNDER_REVIEW", {"IN_PROGRESS"}, user, db)


@app.post("/incidents/{incident_id}/resolve")
async def resolve_incident(incident_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    return await _change_incident_status(incident_id, "RESOLVED", {"UNDER_REVIEW"}, user, db, True)


@app.post("/incidents/{incident_id}/close")
async def close_incident(incident_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    return await _change_incident_status(incident_id, "CLOSED", {"RESOLVED"}, user, db, True)


@app.post("/incidents/{incident_id}/reopen")
async def reopen_incident(incident_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    return await _change_incident_status(incident_id, "REOPENED", {"RESOLVED", "CLOSED"}, user, db, True)


@app.post("/incidents/{incident_id}/comments")
async def comment_incident(incident_id: str, body: CommentBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    incident = await _incident_or_404(db, incident_id)
    content = body.content.strip()
    if not content:
        raise HTTPException(422, "El comentario no puede estar vacío.")
    if incident.status == "CLOSED":
        raise HTTPException(409, "No se puede comentar una incidencia cerrada.")
    db.add(IncidentComment(id=_id(), incident_id=incident.id, user_id=user.id, content=content))
    await db.commit()
    return {"ok": True}


@app.get("/mobile/team/workload")
async def team_workload(
    include_inactive: bool = False,
    user: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_lead(user)
    return await _team_workload_data(db, include_inactive)


@app.get("/reports/projects")
async def projects_report(
    report_format: str = Query(default="pdf", alias="format", pattern="^(pdf|xlsx)$"),
    project_id: str | None = None,
    user: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_lead(user)
    scope, rows = await _project_report_data(db, project_id)
    suffix = project_id or "todos"
    return _report_response(
        report_format,
        f"corestream_proyectos_{suffix}_{datetime.now(timezone.utc):%Y%m%d}",
        "Estado de proyectos",
        scope,
        ["Proyecto", "Épicas", "Tickets", "Completados", "Pendientes", "Atrasados"],
        rows,
    )


@app.get("/reports/team")
async def team_report(
    report_format: str = Query(default="pdf", alias="format", pattern="^(pdf|xlsx)$"),
    include_inactive: bool = False,
    user: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_lead(user)
    workload = await _team_workload_data(db, include_inactive)
    rows = [
        [
            item["user"]["full_name"],
            item["user"]["role"],
            "Sí" if item["user"]["is_active"] else "No",
            item["active_tickets"],
            item["in_progress"],
            item["blocked"],
            item["done_last_7d"],
            item["open_incidents"],
        ]
        for item in workload
    ]
    return _report_response(
        report_format,
        f"corestream_equipo_{datetime.now(timezone.utc):%Y%m%d}",
        "Carga de trabajo del equipo",
        "Incluye inactivos" if include_inactive else "Solo integrantes activos",
        ["Integrante", "Rol", "Activo", "Tickets activos", "En progreso", "Bloqueados", "Hechos 7 días", "Incidencias"],
        rows,
    )


@app.post("/sla/evaluate")
async def evaluate_sla(
    user: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_lead(user)
    return {"escalated_count": await _evaluate_slas(db)}


@app.post("/tickets/{ticket_id}/assign")
async def assign_ticket(ticket_id: str, body: AssignBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    _require_lead(user)
    ticket = await _ticket_or_404(db, ticket_id)
    if ticket.status == "DONE":
        raise HTTPException(409, "No se puede reasignar un ticket completado.")
    if not await db.get(User, body.assignee_id):
        raise HTTPException(404, "Usuario no encontrado.")
    ticket.assignee_id = body.assignee_id
    await _add_ticket_event(db, ticket, user, "ASSIGNED", body.comment)
    await _notify(db, body.assignee_id, "TICKET_ASSIGNED", f"Se te asignó el ticket #{ticket.number}.", ticket_id=ticket.id)
    await db.commit()
    return {"ok": True}


@app.post("/tickets/{ticket_id}/start")
async def start_ticket(ticket_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ticket = await _ticket_or_404(db, ticket_id)
    if ticket.assignee_id != user.id or ticket.status not in {"TODO", "REDIRECTED"}:
        raise HTTPException(403, "No puedes iniciar este ticket.")
    ticket.status = "IN_PROGRESS"
    await _add_ticket_event(db, ticket, user, "STATUS_CHANGED", "IN_PROGRESS")
    await db.commit()
    return {"ok": True}


@app.post("/tickets/{ticket_id}/complete")
async def complete_ticket(ticket_id: str, body: CompleteBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ticket = await _ticket_or_404(db, ticket_id)
    if ticket.assignee_id != user.id or ticket.status != "IN_PROGRESS":
        raise HTTPException(403, "No puedes completar este ticket.")
    ticket.status = "DONE"
    ticket.completed_at = utcnow()
    ticket.pr_link = body.pr_link
    await _add_ticket_event(db, ticket, user, "COMPLETED", body.pr_link)
    await db.commit()
    return {"ok": True}


@app.post("/tickets/{ticket_id}/question")
async def question_ticket(ticket_id: str, body: QuestionBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ticket = await _ticket_or_404(db, ticket_id)
    if ticket.assignee_id != user.id or ticket.status != "IN_PROGRESS":
        raise HTTPException(403, "No puedes bloquear este ticket.")
    ticket.status = "BLOCKED"
    await _add_ticket_event(db, ticket, user, "QUESTION_RAISED", body.question_text)
    await db.commit()
    return {"ok": True}


@app.post("/tickets/{ticket_id}/resolve-question")
async def resolve_question(ticket_id: str, body: ResolutionBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ticket = await _ticket_or_404(db, ticket_id)
    if ticket.status != "BLOCKED" or (ticket.assignee_id != user.id and user.role not in {"ADMIN", "GROUP_LEADER"}):
        raise HTTPException(403, "No puedes resolver este bloqueo.")
    ticket.status = "IN_PROGRESS"
    await _add_ticket_event(db, ticket, user, "QUESTION_RESOLVED", body.resolution_text)
    await db.commit()
    return {"ok": True}


@app.post("/tickets/{ticket_id}/redirect")
async def redirect_ticket(ticket_id: str, body: RedirectBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    ticket = await _ticket_or_404(db, ticket_id)
    if ticket.assignee_id != user.id or ticket.status != "IN_PROGRESS":
        raise HTTPException(403, "No puedes redirigir este ticket.")
    ticket.assignee_id = body.to_user_id
    ticket.status = "REDIRECTED"
    await _add_ticket_event(db, ticket, user, "REDIRECTED", body.reason)
    await _notify(db, body.to_user_id, "REDIRECTED", f"Se te redirigió el ticket #{ticket.number}.", ticket_id=ticket.id)
    await db.commit()
    return {"ok": True}


@app.put("/subtasks/{subtask_id}")
async def update_subtask(subtask_id: str, body: SubtaskBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    subtask = await db.get(Subtask, subtask_id)
    if not subtask:
        raise HTTPException(404, "Subtarea no encontrada.")
    subtask.is_completed = body.is_completed
    await db.commit()
    return {"ok": True}


@app.post("/tickets/")
async def create_ticket(body: CreateTicketBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    _require_lead(user)
    if not await db.get(Epic, body.epic_id):
        raise HTTPException(404, "Épica no encontrada.")
    number = (await db.scalar(select(func.max(Ticket.number)))) or 100
    ticket = Ticket(
        id=_id(),
        number=number + 1,
        epic_id=body.epic_id,
        title=body.title.strip(),
        description="",
        priority=body.priority,
        assignee_id=body.assignee_id,
        created_by_id=user.id,
    )
    db.add(ticket)
    await db.flush()
    started_at = datetime.now(timezone.utc)
    target_minutes = _sla_target("TICKET", ticket.priority)
    db.add(
        SlaRecord(
            id=f"TICKET:{ticket.id}",
            item_type="TICKET",
            item_id=ticket.id,
            policy_key=ticket.priority,
            target_minutes=target_minutes,
            started_at=started_at,
            due_at=started_at + timedelta(minutes=target_minutes),
        )
    )
    await _add_ticket_event(db, ticket, user, "CREATED")
    await _notify(db, body.assignee_id, "TICKET_ASSIGNED", f"Se te asignó el ticket #{ticket.number}.", ticket_id=ticket.id)
    await db.commit()
    return {"id": ticket.id, "number": ticket.number}


@app.get("/notifications/")
async def notifications(limit: int = 50, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.scalars(
            select(Notification)
            .where(Notification.user_id == user.id)
            .order_by(Notification.created_at.desc())
            .limit(min(limit, 100))
        )
    ).all()
    return [
        {
            "id": row.id,
            "type": row.type,
            "message": row.message,
            "is_read": row.is_read,
            "ticket_id": row.ticket_id,
            "incident_id": row.incident_id,
            "created_at": _iso(row.created_at),
        }
        for row in rows
    ]


@app.get("/notifications/unread-count")
async def unread_count(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    count = await db.scalar(
        select(func.count()).select_from(Notification).where(
            Notification.user_id == user.id, Notification.is_read.is_(False)
        )
    )
    return {"count": count or 0}


@app.post("/notifications/mark-read")
async def mark_read(body: MarkReadBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.scalars(
            select(Notification).where(
                Notification.user_id == user.id, Notification.id.in_(body.notification_ids)
            )
        )
    ).all()
    for row in rows:
        row.is_read = True
    await db.commit()
    return {"ok": True}


@app.post("/notifications/mark-all-read")
async def mark_all_read(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.scalars(select(Notification).where(Notification.user_id == user.id))).all()
    for row in rows:
        row.is_read = True
    await db.commit()
    return {"ok": True}


@app.post("/devices/")
async def register_device(
    body: DeviceBody,
    user: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
):
    device = await db.scalar(
        select(PushDevice).where(PushDevice.fcm_token == body.fcm_token)
    )
    if device:
        device.user_id = user.id
        device.platform = body.platform
        device.is_active = True
    else:
        device = PushDevice(
            id=_id(),
            user_id=user.id,
            fcm_token=body.fcm_token,
            platform=body.platform,
        )
        db.add(device)
    await db.commit()
    return {"id": device.id, "active": device.is_active}


@app.websocket("/ws/mobile/notifications")
async def websocket_notifications(websocket: WebSocket, token: str):
    claims = read_access_claims(token)
    if not claims:
        await websocket.close(code=1008)
        return
    user_id, session_id = claims
    async with SessionLocal() as db:
        session = await db.get(SessionToken, session_id)
        if not session or session.revoked or session.user_id != user_id:
            await websocket.close(code=1008)
            return
    await websocket.accept()
    try:
        while True:
            await websocket.send_json({"type": "ping"})
            await asyncio.sleep(20)
    except (WebSocketDisconnect, RuntimeError):
        return
