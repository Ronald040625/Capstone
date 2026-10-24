from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import (
    Epic,
    Incident,
    IncidentComment,
    Notification,
    Project,
    Subtask,
    Ticket,
    TicketEvent,
    User,
)
from .security import hash_password


async def seed_database(db: AsyncSession) -> None:
    count = await db.scalar(select(func.count()).select_from(User))
    if count:
        return

    now = datetime.now(timezone.utc)
    users = [
        User(
            id="u-admin",
            full_name="Ana Torres",
            email="ana@corestream.cl",
            password_hash=hash_password("CoreStream123!"),
            role="ADMIN",
            specialty="Administración de plataforma",
        ),
        User(
            id="u-leader",
            full_name="Luis Vega",
            email="luis@corestream.cl",
            password_hash=hash_password("CoreStream123!"),
            role="GROUP_LEADER",
            specialty="Líder de desarrollo",
        ),
        User(
            id="u-diego",
            full_name="Diego Ramos",
            email="diego@corestream.cl",
            password_hash=hash_password("CoreStream123!"),
            role="DEVELOPER",
            specialty="Backend",
        ),
        User(
            id="u-sofia",
            full_name="Sofía Márquez",
            email="sofia@corestream.cl",
            password_hash=hash_password("CoreStream123!"),
            role="DEVELOPER",
            specialty="Frontend",
        ),
    ]
    projects = [
        Project(id="p-portal", name="Portal Clientes"),
        Project(id="p-pagos", name="API Pagos"),
        Project(id="p-mobile", name="Aplicación Mobile"),
    ]
    epics = [
        Epic(id="e-auth", project_id="p-portal", name="Autenticación", order_index=1),
        Epic(id="e-pay", project_id="p-pagos", name="Procesamiento de pagos", order_index=1),
        Epic(id="e-app", project_id="p-mobile", name="MVP móvil", order_index=1),
    ]
    tickets = [
        Ticket(
            id="t-auth",
            number=101,
            epic_id="e-auth",
            title="Renovar sesión del usuario",
            description="Mantener la sesión activa usando refresh token.",
            status="IN_PROGRESS",
            priority="HIGH",
            assignee_id="u-diego",
            created_by_id="u-leader",
            due_date=now + timedelta(days=2),
        ),
        Ticket(
            id="t-pay",
            number=102,
            epic_id="e-pay",
            title="Validar respuesta del proveedor",
            description="Resolver el bloqueo del webhook de pagos.",
            status="BLOCKED",
            priority="URGENT",
            assignee_id="u-sofia",
            created_by_id="u-leader",
            due_date=now - timedelta(days=1),
        ),
        Ticket(
            id="t-ui",
            number=103,
            epic_id="e-app",
            title="Completar vista de incidencias",
            description="Terminar filtros, detalle y comentarios.",
            status="DONE",
            priority="HIGH",
            assignee_id="u-diego",
            created_by_id="u-admin",
            completed_at=now - timedelta(days=2),
            pr_link="https://github.com/Ronald040625/Capstone/pull/1",
        ),
        Ticket(
            id="t-workload",
            number=104,
            epic_id="e-app",
            title="Mostrar carga del equipo",
            description="Agregar los contadores solicitados para cada integrante.",
            status="TODO",
            priority="MEDIUM",
            assignee_id="u-diego",
            created_by_id="u-leader",
            due_date=now + timedelta(days=4),
        ),
    ]
    incidents = [
        Incident(
            id="i-login",
            number=57,
            project_id="p-portal",
            title="La sesión expira antes de tiempo",
            description="El usuario vuelve al login antes del tiempo configurado.",
            category="CRITICAL_ERROR",
            severity="HIGH",
            status="IN_PROGRESS",
            reporter_id="u-sofia",
            assignee_id="u-diego",
            created_at=now - timedelta(hours=5),
        ),
        Incident(
            id="i-lang",
            number=58,
            project_id="p-mobile",
            title="El selector de idioma no persiste",
            description="Al volver a entrar debe mantenerse el idioma elegido.",
            category="NON_CRITICAL_ERROR",
            severity="MEDIUM",
            status="OPEN",
            reporter_id="u-admin",
            assignee_id=None,
            created_at=now - timedelta(hours=3),
        ),
        Incident(
            id="i-webhook",
            number=59,
            project_id="p-pagos",
            title="Webhook duplicado con respuesta lenta",
            description="El proveedor procesa dos veces el mismo evento.",
            category="CRITICAL_ERROR",
            severity="CRITICAL",
            status="UNDER_REVIEW",
            reporter_id="u-sofia",
            assignee_id="u-sofia",
            created_at=now - timedelta(hours=1),
        ),
    ]

    db.add_all(users + projects + epics + tickets + incidents)
    await db.flush()
    db.add_all(
        [
            Subtask(id="s-1", ticket_id="t-auth", title="Crear renovación", is_completed=True),
            Subtask(id="s-2", ticket_id="t-auth", title="Agregar pruebas", is_completed=False),
            TicketEvent(
                id="te-1",
                ticket_id="t-auth",
                user_id="u-leader",
                event_type="ASSIGNED",
                text="Asignado a Diego Ramos",
                created_at=now - timedelta(days=1),
            ),
            IncidentComment(
                id="ic-1",
                incident_id="i-login",
                user_id="u-sofia",
                content="Ocurre después de aproximadamente veinte minutos.",
                created_at=now - timedelta(hours=4),
            ),
            IncidentComment(
                id="ic-2",
                incident_id="i-login",
                user_id="u-diego",
                content="Estoy revisando la renovación del token.",
                created_at=now - timedelta(hours=2),
            ),
            Notification(
                id="n-1",
                user_id="u-diego",
                type="INCIDENT_ASSIGNED",
                message="Se te asignó la incidencia INC-57.",
                incident_id="i-login",
                created_at=now - timedelta(hours=5),
            ),
            Notification(
                id="n-2",
                user_id="u-admin",
                type="SYSTEM",
                message="El MVP persistente está disponible.",
                created_at=now - timedelta(minutes=30),
            ),
        ]
    )
    await db.commit()
