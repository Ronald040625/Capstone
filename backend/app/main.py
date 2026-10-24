import asyncio
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect
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
    SessionToken,
    Subtask,
    Ticket,
    TicketEvent,
    User,
    utcnow,
)
from .security import (
    create_access_token,
    create_refresh_token,
    read_access_token,
    verify_password,
)
from .seed import seed_database


class LoginBody(BaseModel):
    email: str
    password: str


class DemoLoginBody(BaseModel):
    user_id: str


class LogoutBody(BaseModel):
    refresh_token: str | None = None


class RefreshBody(BaseModel):
    refresh_token: str


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
    yield
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
    user_id = read_access_token(authorization.removeprefix("Bearer ").strip())
    user = await db.get(User, user_id) if user_id else None
    if not user or not user.is_active:
        raise HTTPException(401, "Sesión no válida.")
    return user


async def _create_session(db: AsyncSession, user: User) -> dict:
    refresh = create_refresh_token()
    db.add(SessionToken(token=refresh, user_id=user.id))
    await db.commit()
    return {
        "access_token": create_access_token(user.id),
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


def _incident_json(incident: Incident, users: dict[str, User]) -> dict:
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
    token = await db.get(SessionToken, body.refresh_token)
    if not token or token.revoked:
        raise HTTPException(401, "La sesión ya no está vigente.")
    user = await db.get(User, token.user_id)
    if not user or not user.is_active:
        raise HTTPException(401, "La sesión ya no está vigente.")
    return {"access_token": create_access_token(user.id), "token_type": "bearer"}


@app.post("/auth/logout")
async def logout(
    body: LogoutBody,
    user: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.refresh_token:
        token = await db.get(SessionToken, body.refresh_token)
        if token and token.user_id == user.id:
            token.revoked = True
            await db.commit()
    return {"ok": True}


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
    assignee = await db.get(User, ticket.assignee_id) if ticket.assignee_id else None
    creator = await db.get(User, ticket.created_by_id)
    return {
        "ticket": {
            **_ticket_summary(ticket),
            "pr_link": ticket.pr_link,
            "time_spent_seconds": 0,
            "blocked_time_seconds": 0,
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
    return [_incident_json(incident, users) for incident in rows]


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
    return [_incident_json(incident, users) for incident in rows]


@app.get("/incidents/{incident_id}")
async def incident_detail(incident_id: str, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    incident = await _incident_or_404(db, incident_id)
    return _incident_json(incident, await _users_by_id(db))


@app.post("/incidents/{incident_id}/assign")
async def assign_incident(incident_id: str, body: AssignBody, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    _require_lead(user)
    incident = await _incident_or_404(db, incident_id)
    if not await db.get(User, body.assignee_id):
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
async def team_workload(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    _require_lead(user)
    users = (await db.scalars(select(User).where(User.is_active.is_(True)).order_by(User.full_name))).all()
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
async def register_device(user: User = Depends(current_user)):
    return {"ok": True}


@app.websocket("/ws/mobile/notifications")
async def websocket_notifications(websocket: WebSocket, token: str):
    user_id = read_access_token(token)
    if not user_id:
        await websocket.close(code=1008)
        return
    await websocket.accept()
    try:
        while True:
            await websocket.send_json({"type": "ping"})
            await asyncio.sleep(20)
    except (WebSocketDisconnect, RuntimeError):
        return
