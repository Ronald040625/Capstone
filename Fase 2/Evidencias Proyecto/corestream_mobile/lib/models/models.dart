/// Modelos de dominio de CoreStream (espejo del backend).
///
/// Jerarquía: Project (Application) → Epic → Ticket → Subtask, más
/// Incidencias, Notificaciones y Usuarios con roles.
library;

import 'package:flutter/material.dart' show Color;

// ----------------------------------------------------------------- enums

enum UserRole { admin, groupLeader, developer }

enum TicketStatus { todo, inProgress, blocked, redirected, done }

enum TicketPriority { low, medium, high, urgent }

enum IncidentStatus {
  open,
  inProgress,
  underReview,
  resolved,
  closed,
  reopened
}

enum IncidentSeverity { critical, high, medium, low }

enum IncidentCategory {
  newFeature,
  criticalError,
  nonCriticalError,
  usabilityIssue
}

enum NotificationKind {
  assignment,
  question,
  redirect,
  completion,
  system,
  incident
}

// Conversión wire-format (API) <-> enum. Los nombres del backend van en
// MAYÚSCULAS_CON_GUION_BAJO.
extension UserRoleWire on UserRole {
  String get wire => switch (this) {
        UserRole.admin => 'ADMIN',
        UserRole.groupLeader => 'GROUP_LEADER',
        UserRole.developer => 'DEVELOPER',
      };
  static UserRole parse(String v) => switch (v) {
        'ADMIN' => UserRole.admin,
        'GROUP_LEADER' => UserRole.groupLeader,
        _ => UserRole.developer,
      };
}

extension TicketStatusWire on TicketStatus {
  String get wire => switch (this) {
        TicketStatus.todo => 'TODO',
        TicketStatus.inProgress => 'IN_PROGRESS',
        TicketStatus.blocked => 'BLOCKED',
        TicketStatus.redirected => 'REDIRECTED',
        TicketStatus.done => 'DONE',
      };
  static TicketStatus parse(String v) => switch (v) {
        'IN_PROGRESS' => TicketStatus.inProgress,
        'BLOCKED' => TicketStatus.blocked,
        'REDIRECTED' => TicketStatus.redirected,
        'DONE' => TicketStatus.done,
        _ => TicketStatus.todo,
      };
}

extension TicketPriorityWire on TicketPriority {
  String get wire => name.toUpperCase();
  static TicketPriority parse(String v) => switch (v) {
        'LOW' => TicketPriority.low,
        'HIGH' => TicketPriority.high,
        'URGENT' => TicketPriority.urgent,
        _ => TicketPriority.medium,
      };
}

extension IncidentStatusWire on IncidentStatus {
  String get wire => switch (this) {
        IncidentStatus.open => 'OPEN',
        IncidentStatus.inProgress => 'IN_PROGRESS',
        IncidentStatus.underReview => 'UNDER_REVIEW',
        IncidentStatus.resolved => 'RESOLVED',
        IncidentStatus.closed => 'CLOSED',
        IncidentStatus.reopened => 'REOPENED',
      };
  static IncidentStatus parse(String v) => switch (v) {
        'IN_PROGRESS' => IncidentStatus.inProgress,
        'UNDER_REVIEW' => IncidentStatus.underReview,
        'RESOLVED' => IncidentStatus.resolved,
        'CLOSED' => IncidentStatus.closed,
        'REOPENED' => IncidentStatus.reopened,
        _ => IncidentStatus.open,
      };
}

extension IncidentSeverityWire on IncidentSeverity {
  String get wire => name.toUpperCase();
  static IncidentSeverity parse(String v) => switch (v) {
        'CRITICAL' => IncidentSeverity.critical,
        'HIGH' => IncidentSeverity.high,
        'LOW' => IncidentSeverity.low,
        _ => IncidentSeverity.medium,
      };
}

extension IncidentCategoryWire on IncidentCategory {
  String get wire => switch (this) {
        IncidentCategory.newFeature => 'NEW_FEATURE',
        IncidentCategory.criticalError => 'CRITICAL_ERROR',
        IncidentCategory.nonCriticalError => 'NON_CRITICAL_ERROR',
        IncidentCategory.usabilityIssue => 'USABILITY_ISSUE',
      };
  static IncidentCategory parse(String v) => switch (v) {
        'NEW_FEATURE' => IncidentCategory.newFeature,
        'CRITICAL_ERROR' => IncidentCategory.criticalError,
        'USABILITY_ISSUE' => IncidentCategory.usabilityIssue,
        _ => IncidentCategory.nonCriticalError,
      };
}

extension NotificationKindWire on NotificationKind {
  static NotificationKind parse(String v) => switch (v) {
        'ASSIGNMENT' || 'TICKET_ASSIGNED' => NotificationKind.assignment,
        'QUESTION' || 'QUESTION_ASKED' => NotificationKind.question,
        'REDIRECT' || 'REDIRECTED' => NotificationKind.redirect,
        'COMPLETION' || 'TICKET_COMPLETED' => NotificationKind.completion,
        'INCIDENT' ||
        'INCIDENT_REPORTED' ||
        'INCIDENT_ASSIGNED' =>
          NotificationKind.incident,
        _ => NotificationKind.system,
      };
}

// ----------------------------------------------------------------- entidades

class User {
  const User({
    required this.id,
    required this.fullName,
    required this.role,
    this.specialty,
    this.avatarColor = const Color(0xFF4C8DFF),
    this.isActive = true,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? specialty;
  final Color avatarColor;
  final bool isActive;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  bool get isLead => role == UserRole.admin || role == UserRole.groupLeader;
}

class Project {
  const Project(
      {required this.id,
      required this.name,
      required this.code,
      required this.color});

  final String id;
  final String name;
  final String code;
  final Color color;
}

class Epic {
  const Epic(
      {required this.id,
      required this.projectId,
      required this.name,
      this.orderIndex = 0});

  final String id;
  final String projectId;
  final String name;
  final int orderIndex;
}

class Subtask {
  Subtask({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  bool done;
}

/// Evento del historial de un ticket.
class TicketEvent {
  const TicketEvent({
    required this.type,
    required this.userId,
    required this.ts,
    this.text,
    this.toUserId,
    this.fromStatus,
    this.toStatus,
  });

  /// CREATED | ASSIGNED | STATUS | QUESTION | RESOLVED | REDIRECTED |
  /// COMPLETED | COMMENT
  final String type;
  final String userId;
  final DateTime ts;
  final String? text;
  final String? toUserId;
  final TicketStatus? fromStatus;
  final TicketStatus? toStatus;
}

class Ticket {
  Ticket({
    required this.id,
    required this.number,
    required this.epicId,
    required this.title,
    required this.description,
    this.status = TicketStatus.todo,
    this.priority = TicketPriority.medium,
    this.assigneeId,
    this.createdById,
    this.dueDate,
    this.spentSeconds = 0,
    this.blockedSeconds = 0,
    this.runningSince,
    this.prLink,
    List<Subtask>? subtasks,
    List<TicketEvent>? events,
  })  : subtasks = subtasks ?? [],
        events = events ?? [];

  final String id;
  final int number;
  final String epicId;
  String title;
  String description;
  TicketStatus status;
  TicketPriority priority;
  String? assigneeId;
  String? createdById;
  DateTime? dueDate;

  /// Segundos acumulados confirmados; si [runningSince] no es null, el tiempo
  /// mostrado es spentSeconds + (ahora - runningSince).
  int spentSeconds;
  int blockedSeconds;
  DateTime? runningSince;
  String? prLink;
  final List<Subtask> subtasks;
  final List<TicketEvent> events;

  bool get isOverdue =>
      dueDate != null &&
      status != TicketStatus.done &&
      dueDate!.isBefore(DateTime.now());

  int get liveSpentSeconds =>
      spentSeconds +
      (runningSince != null
          ? DateTime.now().difference(runningSince!).inSeconds
          : 0);

  int get subtasksDone => subtasks.where((s) => s.done).length;
}

class IncidentComment {
  const IncidentComment(
      {required this.userId, required this.text, required this.ts});

  final String userId;
  final String text;
  final DateTime ts;
}

class Incident {
  Incident({
    required this.id,
    required this.number,
    required this.projectId,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    this.status = IncidentStatus.open,
    required this.reporterId,
    this.assigneeId,
    required this.createdAt,
    List<IncidentComment>? comments,
  }) : comments = comments ?? [];

  final String id;
  final int number;
  final String projectId;
  final String title;
  final String description;
  final IncidentCategory category;
  final IncidentSeverity severity;
  IncidentStatus status;
  final String reporterId;
  String? assigneeId;
  final DateTime createdAt;
  final List<IncidentComment> comments;

  bool get isOpen =>
      status != IncidentStatus.resolved && status != IncidentStatus.closed;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.message,
    required this.ts,
    this.read = false,
    this.ticketId,
    this.incidentId,
  });

  final String id;
  final NotificationKind kind;
  final String message;
  final DateTime ts;
  bool read;
  final String? ticketId;
  final String? incidentId;
}

// ----------------------------------------------------------------- permisos

/// Acciones disponibles sobre un ticket para el usuario actual.
///
/// Espejo exacto de `mobile_api/services/permission_service.py`: la app pinta
/// botones con esto (o con el bloque `permissions` del endpoint /mobile en
/// modo API), pero el servidor siempre re-valida.
class TicketPermissions {
  const TicketPermissions({
    this.canAssign = false,
    this.canStart = false,
    this.canComplete = false,
    this.canQuestion = false,
    this.canResolveQuestion = false,
    this.canRedirect = false,
    this.canEditSubtasks = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  final bool canAssign;
  final bool canStart;
  final bool canComplete;
  final bool canQuestion;
  final bool canResolveQuestion;
  final bool canRedirect;
  final bool canEditSubtasks;
  final bool canEdit;
  final bool canDelete;

  bool get anyWorkAction =>
      canStart ||
      canComplete ||
      canQuestion ||
      canResolveQuestion ||
      canRedirect;

  static TicketPermissions compute({
    required UserRole role,
    required String userId,
    required TicketStatus status,
    required String? assigneeId,
  }) {
    final isLead = role == UserRole.admin || role == UserRole.groupLeader;
    final isMine = assigneeId != null && assigneeId == userId;
    return TicketPermissions(
      canAssign: isLead && status != TicketStatus.done,
      canStart: isMine &&
          (status == TicketStatus.todo || status == TicketStatus.redirected),
      canComplete: isMine && status == TicketStatus.inProgress,
      canQuestion: isMine && status == TicketStatus.inProgress,
      canResolveQuestion: (isMine || isLead) && status == TicketStatus.blocked,
      canRedirect: isMine && status == TicketStatus.inProgress,
      canEditSubtasks: (isMine || isLead) && status != TicketStatus.done,
      canEdit: isLead,
      canDelete: role == UserRole.admin,
    );
  }
}

/// Validación de enlaces de PR (misma regla que el backend).
final RegExp prLinkPattern = RegExp(
  r'^https://(www\.)?(github\.com|gitlab\.com|bitbucket\.org)/\S+',
  caseSensitive: false,
);
