/// Contrato de datos de la app.
///
/// Dos implementaciones:
///   - [DemoRepository]: en memoria, con los datos del wireframe y simulación
///     de eventos del equipo (modo por defecto).
///   - [ApiRepository]: cliente HTTP contra el backend FastAPI (endpoints
///     existentes + paquete mobile_api).
library;

import '../models/models.dart';

// --------------------------------------------------------- agregados de vista

class ProjectSummary {
  const ProjectSummary({
    required this.project,
    required this.epicsCount,
    required this.ticketsTotal,
    required this.ticketsDone,
    required this.overdue,
  });

  final Project project;
  final int epicsCount;
  final int ticketsTotal;
  final int ticketsDone;
  final int overdue;

  int get pending => ticketsTotal - ticketsDone;
  double get progress => ticketsTotal == 0 ? 0 : ticketsDone / ticketsTotal;
}

/// Elemento de la lista "Requiere atención" del dashboard de líderes.
class AttentionItem {
  const AttentionItem.ticket(Ticket t, this.projectName)
      : ticket = t,
        incident = null;
  const AttentionItem.incident(Incident i, this.projectName)
      : incident = i,
        ticket = null;

  final Ticket? ticket;
  final Incident? incident;
  final String projectName;
}

class Dashboard {
  const Dashboard({
    required this.role,
    required this.stats,
    this.projects = const [],
    this.attention = const [],
    this.myTickets = const [],
    this.myIncidents = const [],
  });

  final UserRole role;

  /// Claves para líderes: apps, open, blocked, late.
  /// Claves para developer: mine, prog, doneWeek, incidents.
  final Map<String, int> stats;
  final List<ProjectSummary> projects;
  final List<AttentionItem> attention;
  final List<Ticket> myTickets;
  final List<Incident> myIncidents;
}

class EpicBoard {
  const EpicBoard({required this.epic, required this.tickets});

  final Epic epic;
  final List<Ticket> tickets;

  int get done => tickets.where((t) => t.status == TicketStatus.done).length;
  double get progress => tickets.isEmpty ? 0 : done / tickets.length;
}

class Board {
  const Board({required this.project, required this.epics});

  final Project project;
  final List<EpicBoard> epics;
}

class TicketDetail {
  const TicketDetail({
    required this.ticket,
    required this.epic,
    required this.project,
    required this.permissions,
    this.assignee,
    this.createdBy,
  });

  final Ticket ticket;
  final Epic epic;
  final Project project;
  final TicketPermissions permissions;
  final User? assignee;
  final User? createdBy;
}

class MemberLoad {
  const MemberLoad({
    required this.user,
    required this.activeTickets,
    required this.inProgress,
    required this.blocked,
    required this.doneLast7d,
    required this.openIncidents,
  });

  final User user;
  final int activeTickets;
  final int inProgress;
  final int blocked;
  final int doneLast7d;
  final int openIncidents;
}

// ------------------------------------------------------------------ contrato

abstract class CoreStreamRepository {
  /// Usuarios disponibles para el selector de login (en modo API, el login
  /// real es por email/contraseña; el selector demo se alimenta de /users).
  Future<List<User>> loginOptions();

  Future<User> login(User user);
  Future<void> logout();

  /// Emite cada vez que los datos cambian (acción propia o evento simulado):
  /// los providers que dependen de él se recalculan.
  Stream<int> get changes;

  /// Notificaciones push entrantes para el usuario logueado (toast + campana).
  Stream<AppNotification> get incomingPush;

  Future<Dashboard> fetchDashboard();
  Future<List<ProjectSummary>> fetchProjects();
  Future<Board> fetchBoard(String projectId);
  Future<TicketDetail> fetchTicketDetail(String ticketId);
  Future<List<Incident>> fetchIncidents();
  Future<Incident> fetchIncident(String incidentId);
  Future<List<MemberLoad>> fetchTeamWorkload();
  Future<List<AppNotification>> fetchNotifications();
  Future<int> unreadCount();
  Future<List<User>> fetchUsers();
  User? userById(String? id);
  Project? projectOfTicket(Ticket t);

  // --- acciones de tickets ---
  Future<void> assignTicket(String ticketId, String assigneeId,
      {String? comment});
  Future<void> startTicket(String ticketId);
  Future<void> completeTicket(String ticketId, String prLink);
  Future<void> raiseQuestion(String ticketId, String question);
  Future<void> resolveQuestion(String ticketId, String resolution);
  Future<void> redirectTicket(String ticketId, String toUserId, String reason);
  Future<void> toggleSubtask(String ticketId, String subtaskId, bool done);
  Future<void> createTicket({
    required String epicId,
    required String title,
    required TicketPriority priority,
    String? assigneeId,
  });

  // --- acciones de incidencias ---
  Future<void> takeIncident(String incidentId);
  Future<void> assignIncident(String incidentId, String assigneeId);
  Future<void> setIncidentStatus(String incidentId, IncidentStatus status);
  Future<void> commentIncident(String incidentId, String comment);

  // --- notificaciones ---
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();

  /// Registro del token FCM (no-op en demo; POST /devices/ en API).
  Future<void> registerDevice(String fcmToken, String platform) async {}

  void dispose() {}
}
