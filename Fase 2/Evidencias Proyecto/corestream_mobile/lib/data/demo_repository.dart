/// Repositorio demo: datos del wireframe en memoria + simulación de eventos
/// del equipo cada ~20 s (nueva incidencia, nuevo ticket, completado,
/// pregunta), que generan notificaciones y toasts como pushes reales.
library;

import 'dart:async';

import 'package:flutter/material.dart' show Color;

import '../core/config.dart';
import '../models/models.dart';
import 'repository.dart';

class DemoRepository implements CoreStreamRepository {
  DemoRepository() {
    _seed();
  }

  final _changes = StreamController<int>.broadcast();
  final _push = StreamController<AppNotification>.broadcast();
  int _rev = 0;
  int _idSeq = 0;
  int _ticketNum = 147;
  int _incidentNum = 62;
  Timer? _simTimer;
  int _simStep = 0;
  bool _simEnabled = true;

  /// Activa/desactiva la simulación de eventos del equipo (Ajustes).
  bool get simulationEnabled => _simEnabled;
  set simulationEnabled(bool v) {
    _simEnabled = v;
    if (!v) {
      _simTimer?.cancel();
      _simTimer = null;
    } else if (_current != null && _simTimer == null) {
      _startSimulation();
    }
  }

  User? _current;

  late final List<User> _users;
  late final List<Project> _projects;
  late final List<Epic> _epics;
  late final List<Ticket> _tickets;
  late final List<Incident> _incidents;

  /// Notificaciones por usuario (id de usuario -> lista).
  final Map<String, List<AppNotification>> _notifs = {};

  String _nid() => 'demo-${_idSeq++}';

  void _emitChange() {
    _rev++;
    _changes.add(_rev);
  }

  // ------------------------------------------------------------------ seed

  void _seed() {
    _users = const [
      User(
          id: 'u1',
          fullName: 'Ana Torres',
          role: UserRole.admin,
          specialty: 'Arquitectura de soluciones',
          avatarColor: Color(0xFF4C8DFF)),
      User(
          id: 'u2',
          fullName: 'Luis Vega',
          role: UserRole.groupLeader,
          specialty: 'Backend · Líder equipo Pagos',
          avatarColor: Color(0xFF8B7CF6)),
      User(
          id: 'u3',
          fullName: 'Diego Ramos',
          role: UserRole.developer,
          specialty: 'Frontend · Vue / TypeScript',
          avatarColor: Color(0xFF2FBF71)),
      User(
          id: 'u4',
          fullName: 'Sofía Márquez',
          role: UserRole.developer,
          specialty: 'Full-stack · Integraciones',
          avatarColor: Color(0xFFF2A93B)),
      User(
          id: 'u5',
          fullName: 'Marco Ibáñez',
          role: UserRole.developer,
          specialty: 'QA · Automatización',
          avatarColor: Color(0xFFF0554E)),
    ];

    _projects = const [
      Project(
          id: 'a1',
          name: 'Portal Clientes',
          code: 'PC',
          color: Color(0xFF4C8DFF)),
      Project(
          id: 'a2', name: 'API Pagos', code: 'AP', color: Color(0xFF2FBF71)),
      Project(
          id: 'a3',
          name: 'App Logística',
          code: 'AL',
          color: Color(0xFF8B7CF6)),
    ];

    _epics = const [
      Epic(id: 'e1', projectId: 'a1', name: 'Autenticación y seguridad'),
      Epic(
          id: 'e2',
          projectId: 'a1',
          name: 'Panel de autogestión',
          orderIndex: 1),
      Epic(id: 'e3', projectId: 'a2', name: 'Conciliación bancaria'),
      Epic(id: 'e4', projectId: 'a2', name: 'Webhooks de pago', orderIndex: 1),
      Epic(id: 'e5', projectId: 'a3', name: 'Seguimiento de flotas'),
    ];

    final now = DateTime.now();
    DateTime days(int n) => now.subtract(Duration(days: n));
    DateTime inDays(int n) => now.add(Duration(days: n));
    DateTime hours(int n) => now.subtract(Duration(hours: n));

    _tickets = [
      Ticket(
        id: 't1',
        number: 132,
        epicId: 'e1',
        title: 'Implementar login con doble factor (TOTP)',
        description:
            'Añadir verificación TOTP tras la contraseña. Incluir códigos de respaldo y flujo de recuperación. Criterio de aceptación: compatible con Google Authenticator y 1Password.',
        status: TicketStatus.inProgress,
        priority: TicketPriority.high,
        assigneeId: 'u3',
        createdById: 'u2',
        dueDate: inDays(2),
        spentSeconds: 4 * 3600 + 22 * 60,
        blockedSeconds: 35 * 60,
        runningSince: now.subtract(const Duration(minutes: 12)),
        subtasks: [
          Subtask(id: 's1', title: 'Pantalla de enrolamiento TOTP', done: true),
          Subtask(
              id: 's2', title: 'Validación de código de 6 dígitos', done: true),
          Subtask(id: 's3', title: 'Códigos de respaldo descargables'),
          Subtask(id: 's4', title: 'Tests E2E del flujo completo'),
        ],
        events: [
          TicketEvent(type: 'CREATED', userId: 'u2', ts: days(4)),
          TicketEvent(
              type: 'ASSIGNED', userId: 'u2', toUserId: 'u3', ts: days(4)),
          TicketEvent(
              type: 'STATUS',
              userId: 'u3',
              fromStatus: TicketStatus.todo,
              toStatus: TicketStatus.inProgress,
              ts: days(3)),
          TicketEvent(
              type: 'COMMENT',
              userId: 'u2',
              text:
                  'Prioriza la compatibilidad con 1Password, lo pidió el cliente.',
              ts: days(1)),
        ],
      ),
      Ticket(
        id: 't2',
        number: 128,
        epicId: 'e1',
        title: 'Bloqueo de cuenta tras 5 intentos fallidos',
        description:
            'Política de bloqueo temporal (15 min) con aviso por correo al usuario.',
        status: TicketStatus.blocked,
        priority: TicketPriority.medium,
        assigneeId: 'u4',
        createdById: 'u2',
        dueDate: inDays(1),
        spentSeconds: 2 * 3600 + 10 * 60,
        blockedSeconds: 3 * 3600,
        subtasks: [
          Subtask(id: 's5', title: 'Contador de intentos en Redis', done: true),
          Subtask(id: 's6', title: 'Plantilla de correo de aviso'),
        ],
        events: [
          TicketEvent(type: 'CREATED', userId: 'u2', ts: days(6)),
          TicketEvent(
              type: 'ASSIGNED', userId: 'u2', toUserId: 'u4', ts: days(6)),
          TicketEvent(
              type: 'QUESTION',
              userId: 'u4',
              text:
                  '¿El bloqueo aplica también a los accesos por API o solo al portal web?',
              ts: hours(5)),
        ],
      ),
      Ticket(
        id: 't3',
        number: 141,
        epicId: 'e2',
        title: 'Descarga de facturas en PDF desde el panel',
        description:
            'El cliente debe poder descargar sus últimas 24 facturas en PDF con firma digital.',
        priority: TicketPriority.medium,
        createdById: 'u1',
        dueDate: inDays(6),
        subtasks: [
          Subtask(id: 's7', title: 'Endpoint GET /invoices/:id/pdf'),
          Subtask(id: 's8', title: 'Listado con paginación'),
        ],
        events: [TicketEvent(type: 'CREATED', userId: 'u1', ts: days(2))],
      ),
      Ticket(
        id: 't4',
        number: 139,
        epicId: 'e2',
        title: 'Editar datos fiscales con validación de NIF/CIF',
        description:
            'Formulario de datos fiscales con validación en tiempo real y verificación contra el censo.',
        status: TicketStatus.done,
        priority: TicketPriority.low,
        assigneeId: 'u5',
        createdById: 'u2',
        dueDate: days(1),
        spentSeconds: 6 * 3600 + 45 * 60,
        prLink: 'https://github.com/wellq/portal/pull/412',
        subtasks: [
          Subtask(id: 's9', title: 'Validador NIF/CIF', done: true),
          Subtask(id: 's10', title: 'Mensajes de error accesibles', done: true),
        ],
        events: [
          TicketEvent(type: 'CREATED', userId: 'u2', ts: days(9)),
          TicketEvent(type: 'COMPLETED', userId: 'u5', ts: days(1)),
        ],
      ),
      Ticket(
        id: 't5',
        number: 145,
        epicId: 'e3',
        title: 'Matching automático de transferencias SEPA',
        description:
            'Cruce automático de transferencias entrantes contra facturas pendientes usando referencia estructurada. Tolerancia de ±0,01 €.',
        status: TicketStatus.inProgress,
        priority: TicketPriority.urgent,
        assigneeId: 'u4',
        createdById: 'u2',
        dueDate: days(1),
        spentSeconds: 9 * 3600 + 12 * 60,
        blockedSeconds: 55 * 60,
        subtasks: [
          Subtask(id: 's11', title: 'Parser de extractos CAMT.053', done: true),
          Subtask(
              id: 's12', title: 'Motor de matching por referencia', done: true),
          Subtask(id: 's13', title: 'Cola de revisión manual'),
          Subtask(id: 's14', title: 'Informe diario de no conciliados'),
        ],
        events: [
          TicketEvent(type: 'CREATED', userId: 'u2', ts: days(8)),
          TicketEvent(
              type: 'ASSIGNED', userId: 'u2', toUserId: 'u4', ts: days(8)),
        ],
      ),
      Ticket(
        id: 't6',
        number: 143,
        epicId: 'e3',
        title: 'Alertas de descuadre superior a 50 €',
        description:
            'Notificar al equipo de finanzas cuando el descuadre diario supere el umbral configurable.',
        priority: TicketPriority.high,
        assigneeId: 'u3',
        createdById: 'u1',
        dueDate: inDays(4),
        subtasks: [Subtask(id: 's15', title: 'Umbral configurable por app')],
        events: [
          TicketEvent(type: 'CREATED', userId: 'u1', ts: days(3)),
          TicketEvent(
              type: 'ASSIGNED', userId: 'u1', toUserId: 'u3', ts: days(3)),
        ],
      ),
      Ticket(
        id: 't7',
        number: 137,
        epicId: 'e4',
        title: 'Reintentos exponenciales en webhooks fallidos',
        description:
            'Hasta 6 reintentos con backoff exponencial y firma HMAC en cada entrega.',
        status: TicketStatus.redirected,
        priority: TicketPriority.high,
        assigneeId: 'u3',
        createdById: 'u2',
        dueDate: inDays(3),
        spentSeconds: 3600 + 30 * 60,
        subtasks: [
          Subtask(id: 's16', title: 'Scheduler de reintentos', done: true),
          Subtask(id: 's17', title: 'Panel de entregas fallidas'),
        ],
        events: [
          TicketEvent(type: 'CREATED', userId: 'u2', ts: days(7)),
          TicketEvent(
              type: 'REDIRECTED',
              userId: 'u5',
              toUserId: 'u3',
              text:
                  'Necesita conocimiento del front del panel de entregas; Diego lo tiene fresco.',
              ts: days(2)),
        ],
      ),
      Ticket(
        id: 't8',
        number: 146,
        epicId: 'e5',
        title: 'Mapa en vivo con posiciones GPS cada 30 s',
        description:
            'Websocket con posiciones de la flota y clustering de marcadores en el mapa.',
        status: TicketStatus.inProgress,
        priority: TicketPriority.medium,
        assigneeId: 'u5',
        createdById: 'u1',
        dueDate: inDays(9),
        spentSeconds: 3 * 3600 + 5 * 60,
        subtasks: [
          Subtask(id: 's18', title: 'Canal WS /fleet/positions', done: true),
          Subtask(id: 's19', title: 'Clustering de marcadores'),
          Subtask(id: 's20', title: 'Modo ahorro de datos'),
        ],
        events: [
          TicketEvent(type: 'CREATED', userId: 'u1', ts: days(5)),
          TicketEvent(
              type: 'ASSIGNED', userId: 'u1', toUserId: 'u5', ts: days(5)),
        ],
      ),
      Ticket(
        id: 't9',
        number: 134,
        epicId: 'e5',
        title: 'Firma digital de albaranes en la entrega',
        description:
            'Captura de firma táctil y foto del paquete como prueba de entrega.',
        priority: TicketPriority.low,
        createdById: 'u1',
        dueDate: inDays(14),
        events: [TicketEvent(type: 'CREATED', userId: 'u1', ts: days(1))],
      ),
    ];

    _incidents = [
      Incident(
        id: 'i1',
        number: 57,
        projectId: 'a2',
        title: 'Timeout al conciliar extractos de más de 5 000 líneas',
        description:
            'El proceso de conciliación supera los 30 s y el worker corta la tarea. Ocurre con los extractos de fin de mes de dos clientes grandes.',
        category: IncidentCategory.criticalError,
        severity: IncidentSeverity.critical,
        status: IncidentStatus.inProgress,
        reporterId: 'u2',
        assigneeId: 'u4',
        createdAt: hours(26),
        comments: [
          IncidentComment(
              userId: 'u4',
              text:
                  'Reproducido con el extracto de 8 200 líneas. El cuello está en el parser, no en la BD.',
              ts: hours(20)),
        ],
      ),
      Incident(
        id: 'i2',
        number: 58,
        projectId: 'a1',
        title: 'El selector de idioma no persiste tras cerrar sesión',
        description:
            'Al volver a entrar, el portal vuelve a español aunque el usuario eligió inglés.',
        category: IncidentCategory.nonCriticalError,
        severity: IncidentSeverity.low,
        reporterId: 'u3',
        createdAt: hours(8),
      ),
      Incident(
        id: 'i3',
        number: 55,
        projectId: 'a1',
        title: 'Añadir exportación de movimientos a Excel',
        description:
            'Varios clientes piden exportar el histórico de movimientos a XLSX además del CSV actual.',
        category: IncidentCategory.newFeature,
        severity: IncidentSeverity.medium,
        status: IncidentStatus.underReview,
        reporterId: 'u1',
        assigneeId: 'u3',
        createdAt: days(3),
      ),
      Incident(
        id: 'i4',
        number: 52,
        projectId: 'a3',
        title: 'Contraste insuficiente en el mapa nocturno',
        description:
            'Los marcadores grises apenas se distinguen sobre el tema oscuro del mapa.',
        category: IncidentCategory.usabilityIssue,
        severity: IncidentSeverity.medium,
        status: IncidentStatus.resolved,
        reporterId: 'u5',
        assigneeId: 'u5',
        createdAt: days(6),
      ),
      Incident(
        id: 'i5',
        number: 60,
        projectId: 'a2',
        title: 'Webhook duplicado cuando el receptor responde 5xx lento',
        description:
            'Si el receptor tarda >10 s y devuelve 502, el evento se entrega dos veces.',
        category: IncidentCategory.criticalError,
        severity: IncidentSeverity.high,
        reporterId: 'u4',
        createdAt: hours(3),
      ),
    ];

    // Notificaciones iniciales
    void seedNotif(List<String> userIds, NotificationKind kind, String message,
        {String? ticketId,
        String? incidentId,
        required DateTime ts,
        bool read = false}) {
      for (final uid in userIds) {
        (_notifs[uid] ??= []).add(AppNotification(
          id: _nid(),
          kind: kind,
          message: message,
          ts: ts,
          read: read,
          ticketId: ticketId,
          incidentId: incidentId,
        ));
      }
    }

    seedNotif(['u3'], NotificationKind.assignment,
        'Ana Torres te asignó: “Alertas de descuadre superior a 50 €”',
        ticketId: 't6', ts: days(3), read: true);
    seedNotif(['u1', 'u2'], NotificationKind.question,
        'Sofía Márquez planteó una pregunta en Portal Clientes: “Bloqueo de cuenta tras 5 intentos fallidos”',
        ticketId: 't2', ts: hours(5));
    seedNotif(['u1', 'u2'], NotificationKind.incident,
        'Sofía Márquez reportó una incidencia en API Pagos: “Webhook duplicado cuando el receptor responde 5xx lento”',
        incidentId: 'i5', ts: hours(3));
    seedNotif(['u1', 'u2'], NotificationKind.completion,
        'Marco Ibáñez completó un ticket en Portal Clientes: “Editar datos fiscales con validación de NIF/CIF”',
        ticketId: 't4', ts: days(1), read: true);
    seedNotif(['u3'], NotificationKind.redirect,
        'Marco Ibáñez te asignó: “Reintentos exponenciales en webhooks fallidos”',
        ticketId: 't7', ts: days(2));
  }

  // ----------------------------------------------------------- helpers

  Ticket _ticket(String id) => _tickets.firstWhere((t) => t.id == id);
  Incident _incident(String id) => _incidents.firstWhere((i) => i.id == id);
  Epic _epic(String id) => _epics.firstWhere((e) => e.id == id);
  Project _project(String id) => _projects.firstWhere((p) => p.id == id);

  @override
  User? userById(String? id) {
    if (id == null) return null;
    for (final u in _users) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Project? projectOfTicket(Ticket t) => _project(_epic(t.epicId).projectId);

  List<String> get _leadIds =>
      _users.where((u) => u.isLead).map((u) => u.id).toList();

  void _notify(List<String> userIds, NotificationKind kind, String message,
      {String? ticketId, String? incidentId}) {
    for (final uid in userIds.toSet()) {
      final n = AppNotification(
        id: _nid(),
        kind: kind,
        message: message,
        ts: DateTime.now(),
        ticketId: ticketId,
        incidentId: incidentId,
      );
      (_notifs[uid] ??= []).add(n);
      if (uid == _current?.id) _push.add(n);
    }
  }

  /// Consolida el tiempo del temporizador antes de pausar/detener.
  void _settleTimer(Ticket t) {
    if (t.runningSince != null) {
      t.spentSeconds += DateTime.now().difference(t.runningSince!).inSeconds;
      t.runningSince = null;
    }
  }

  // ----------------------------------------------------------- sesión

  @override
  Future<List<User>> loginOptions() async => _users.take(3).toList();

  @override
  Future<User> login(User user) async {
    _current = user;
    _startSimulation();
    return user;
  }

  @override
  Future<void> logout() async {
    _current = null;
    _simTimer?.cancel();
    _simTimer = null;
  }

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Stream<AppNotification> get incomingPush => _push.stream;

  // ----------------------------------------------------------- lecturas

  ProjectSummary _summary(Project p) {
    final epicIds =
        _epics.where((e) => e.projectId == p.id).map((e) => e.id).toSet();
    final tickets = _tickets.where((t) => epicIds.contains(t.epicId)).toList();
    return ProjectSummary(
      project: p,
      epicsCount: epicIds.length,
      ticketsTotal: tickets.length,
      ticketsDone: tickets.where((t) => t.status == TicketStatus.done).length,
      overdue: tickets.where((t) => t.isOverdue).length,
    );
  }

  @override
  Future<Dashboard> fetchDashboard() async {
    final me = _current!;
    if (me.isLead) {
      final open =
          _tickets.where((t) => t.status != TicketStatus.done).toList();
      final blocked =
          open.where((t) => t.status == TicketStatus.blocked).toList();
      final late = open.where((t) => t.isOverdue).toList();
      final attention = <AttentionItem>[
        for (final t in {...blocked, ...late})
          AttentionItem.ticket(t, projectOfTicket(t)!.name),
        for (final i in _incidents.where((i) =>
            (i.status == IncidentStatus.open ||
                i.status == IncidentStatus.reopened) &&
            (i.severity == IncidentSeverity.critical ||
                i.severity == IncidentSeverity.high)))
          AttentionItem.incident(i, _project(i.projectId).name),
      ];
      return Dashboard(
        role: me.role,
        stats: {
          'apps': _projects.length,
          'open': open.length,
          'blocked': blocked.length,
          'late': late.length,
        },
        projects: _projects.map(_summary).toList(),
        attention: attention.take(10).toList(),
      );
    }
    final mine = _tickets
        .where((t) => t.assigneeId == me.id && t.status != TicketStatus.done)
        .toList()
      ..sort((a, b) =>
          (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final myIncidents =
        _incidents.where((i) => i.assigneeId == me.id && i.isOpen).toList();
    return Dashboard(
      role: me.role,
      stats: {
        'mine': mine.length,
        'prog': mine.where((t) => t.status == TicketStatus.inProgress).length,
        'doneWeek': _tickets
            .where((t) =>
                t.assigneeId == me.id &&
                t.status == TicketStatus.done &&
                t.events
                    .any((e) => e.type == 'COMPLETED' && e.ts.isAfter(weekAgo)))
            .length,
        'incidents': myIncidents.length,
      },
      myTickets: mine,
      myIncidents: myIncidents,
    );
  }

  @override
  Future<List<ProjectSummary>> fetchProjects() async =>
      _projects.map(_summary).toList();

  @override
  Future<Board> fetchBoard(String projectId) async {
    final epics = _epics.where((e) => e.projectId == projectId).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return Board(
      project: _project(projectId),
      epics: [
        for (final e in epics)
          EpicBoard(
              epic: e,
              tickets: _tickets.where((t) => t.epicId == e.id).toList()),
      ],
    );
  }

  @override
  Future<TicketDetail> fetchTicketDetail(String ticketId) async {
    final t = _ticket(ticketId);
    final e = _epic(t.epicId);
    final me = _current!;
    return TicketDetail(
      ticket: t,
      epic: e,
      project: _project(e.projectId),
      assignee: userById(t.assigneeId),
      createdBy: userById(t.createdById),
      permissions: TicketPermissions.compute(
          role: me.role,
          userId: me.id,
          status: t.status,
          assigneeId: t.assigneeId),
    );
  }

  @override
  Future<List<Incident>> fetchIncidents() async {
    final me = _current!;
    final list = me.isLead
        ? _incidents
        : _incidents
            .where((i) =>
                i.assigneeId == me.id ||
                i.reporterId == me.id ||
                i.assigneeId == null)
            .toList();
    final sorted = [...list]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<Incident> fetchIncident(String incidentId) async =>
      _incident(incidentId);

  @override
  Future<List<MemberLoad>> fetchTeamWorkload() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return [
      for (final u in _users)
        MemberLoad(
          user: u,
          activeTickets: _tickets
              .where(
                  (t) => t.assigneeId == u.id && t.status != TicketStatus.done)
              .length,
          inProgress: _tickets
              .where((t) =>
                  t.assigneeId == u.id && t.status == TicketStatus.inProgress)
              .length,
          blocked: _tickets
              .where((t) =>
                  t.assigneeId == u.id && t.status == TicketStatus.blocked)
              .length,
          doneLast7d: _tickets
              .where((t) =>
                  t.assigneeId == u.id &&
                  t.status == TicketStatus.done &&
                  t.events.any(
                      (e) => e.type == 'COMPLETED' && e.ts.isAfter(weekAgo)))
              .length,
          openIncidents:
              _incidents.where((i) => i.assigneeId == u.id && i.isOpen).length,
        ),
    ];
  }

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final list = [...(_notifs[_current!.id] ?? const <AppNotification>[])];
    list.sort((a, b) => b.ts.compareTo(a.ts));
    return list;
  }

  @override
  Future<int> unreadCount() async =>
      (_notifs[_current?.id] ?? const []).where((n) => !n.read).length;

  @override
  Future<List<User>> fetchUsers() async => _users;

  // ----------------------------------------------------------- acciones

  @override
  Future<void> assignTicket(String ticketId, String assigneeId,
      {String? comment}) async {
    final t = _ticket(ticketId);
    final me = _current!;
    t.assigneeId = assigneeId;
    if (t.status == TicketStatus.redirected) t.status = TicketStatus.todo;
    t.events.add(TicketEvent(
        type: 'ASSIGNED',
        userId: me.id,
        toUserId: assigneeId,
        ts: DateTime.now(),
        text: comment));
    if (assigneeId != me.id) {
      _notify([assigneeId], NotificationKind.assignment,
          '${me.fullName} te asignó: “${t.title}”',
          ticketId: t.id);
    }
    _emitChange();
  }

  @override
  Future<void> startTicket(String ticketId) async {
    final t = _ticket(ticketId);
    t.events.add(TicketEvent(
        type: 'STATUS',
        userId: _current!.id,
        fromStatus: t.status,
        toStatus: TicketStatus.inProgress,
        ts: DateTime.now()));
    t.status = TicketStatus.inProgress;
    t.runningSince = DateTime.now();
    _emitChange();
  }

  @override
  Future<void> completeTicket(String ticketId, String prLink) async {
    if (!prLinkPattern.hasMatch(prLink)) {
      throw ArgumentError('pr_invalid');
    }
    final t = _ticket(ticketId);
    final me = _current!;
    _settleTimer(t);
    t.status = TicketStatus.done;
    t.prLink = prLink;
    t.events
        .add(TicketEvent(type: 'COMPLETED', userId: me.id, ts: DateTime.now()));
    _notify(
        _leadIds.where((id) => id != me.id).toList(),
        NotificationKind.completion,
        '${me.fullName} completó un ticket en ${projectOfTicket(t)!.name}: “${t.title}”',
        ticketId: t.id);
    _emitChange();
  }

  @override
  Future<void> raiseQuestion(String ticketId, String question) async {
    final t = _ticket(ticketId);
    final me = _current!;
    _settleTimer(t);
    t.status = TicketStatus.blocked;
    t.events.add(TicketEvent(
        type: 'QUESTION', userId: me.id, text: question, ts: DateTime.now()));
    _notify(
        _leadIds.where((id) => id != me.id).toList(),
        NotificationKind.question,
        '${me.fullName} planteó una pregunta en ${projectOfTicket(t)!.name}: “${t.title}”',
        ticketId: t.id);
    _emitChange();
  }

  @override
  Future<void> resolveQuestion(String ticketId, String resolution) async {
    final t = _ticket(ticketId);
    t.events.add(TicketEvent(
        type: 'RESOLVED',
        userId: _current!.id,
        text: resolution,
        ts: DateTime.now()));
    t.status = TicketStatus.inProgress;
    t.runningSince = DateTime.now();
    _emitChange();
  }

  @override
  Future<void> redirectTicket(
      String ticketId, String toUserId, String reason) async {
    final t = _ticket(ticketId);
    final me = _current!;
    _settleTimer(t);
    t.status = TicketStatus.redirected;
    t.assigneeId = toUserId;
    t.events.add(TicketEvent(
        type: 'REDIRECTED',
        userId: me.id,
        toUserId: toUserId,
        text: reason,
        ts: DateTime.now()));
    _notify([toUserId, ..._leadIds].where((id) => id != me.id).toList(),
        NotificationKind.redirect, '${me.fullName} te asignó: “${t.title}”',
        ticketId: t.id);
    _emitChange();
  }

  @override
  Future<void> toggleSubtask(
      String ticketId, String subtaskId, bool done) async {
    final t = _ticket(ticketId);
    t.subtasks.firstWhere((s) => s.id == subtaskId).done = done;
    _emitChange();
  }

  @override
  Future<void> createTicket({
    required String epicId,
    required String title,
    required TicketPriority priority,
    String? assigneeId,
  }) async {
    final me = _current!;
    final t = Ticket(
      id: _nid(),
      number: ++_ticketNum,
      epicId: epicId,
      title: title,
      description: title,
      priority: priority,
      assigneeId: assigneeId,
      createdById: me.id,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      events: [TicketEvent(type: 'CREATED', userId: me.id, ts: DateTime.now())],
    );
    if (assigneeId != null) {
      t.events.add(TicketEvent(
          type: 'ASSIGNED',
          userId: me.id,
          toUserId: assigneeId,
          ts: DateTime.now()));
    }
    _tickets.add(t);
    if (assigneeId != null && assigneeId != me.id) {
      _notify([assigneeId], NotificationKind.assignment,
          '${me.fullName} te asignó: “${t.title}”',
          ticketId: t.id);
    }
    _notify(
        _leadIds.where((id) => id != me.id).toList(),
        NotificationKind.system,
        '${me.fullName} creó un ticket en ${projectOfTicket(t)!.name}: “${t.title}”',
        ticketId: t.id);
    _emitChange();
  }

  @override
  Future<void> takeIncident(String incidentId) async {
    final i = _incident(incidentId);
    i.assigneeId = _current!.id;
    i.status = IncidentStatus.inProgress;
    _emitChange();
  }

  @override
  Future<void> assignIncident(String incidentId, String assigneeId) async {
    final i = _incident(incidentId);
    final me = _current!;
    i.assigneeId = assigneeId;
    i.status = IncidentStatus.inProgress;
    if (assigneeId != me.id) {
      _notify([assigneeId], NotificationKind.assignment,
          '${me.fullName} te asignó: “${i.title}”',
          incidentId: i.id);
    }
    _emitChange();
  }

  @override
  Future<void> setIncidentStatus(
      String incidentId, IncidentStatus status) async {
    _incident(incidentId).status = status;
    _emitChange();
  }

  @override
  Future<void> commentIncident(String incidentId, String comment) async {
    final text = comment.trim();
    if (text.isEmpty) return;
    _incident(incidentId).comments.add(IncidentComment(
          userId: _current!.id,
          text: text,
          ts: DateTime.now(),
        ));
    _emitChange();
  }

  @override
  Future<void> markNotificationRead(String id) async {
    for (final n in _notifs[_current?.id] ?? const <AppNotification>[]) {
      if (n.id == id) n.read = true;
    }
    _emitChange();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    for (final n in _notifs[_current?.id] ?? const <AppNotification>[]) {
      n.read = true;
    }
    _emitChange();
  }

  @override
  Future<void> registerDevice(String fcmToken, String platform) async {}

  // ----------------------------------------------------------- simulación

  void _startSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    if (!_simEnabled) return;
    _simTimer = Timer.periodic(AppConfig.demoEventInterval, (_) {
      if (!_simEnabled || _current == null) return;
      _runSimStep();
    });
  }

  void _runSimStep() {
    switch (_simStep) {
      case 0:
        {
          // Sofía reporta una incidencia nueva
          final i = Incident(
            id: _nid(),
            number: ++_incidentNum,
            projectId: 'a2',
            title: 'Error 500 al exportar el informe mensual de conciliación',
            description:
                'Al exportar el informe de conciliación del mes, el servidor devuelve 500. Ocurre solo con rangos superiores a 31 días.',
            category: IncidentCategory.criticalError,
            severity: IncidentSeverity.high,
            reporterId: 'u4',
            createdAt: DateTime.now(),
          );
          _incidents.add(i);
          _notify(_leadIds, NotificationKind.incident,
              'Sofía Márquez reportó una incidencia en API Pagos: “${i.title}”',
              incidentId: i.id);
        }
      case 1:
        {
          // Luis crea un ticket y lo asigna a Diego
          final t = Ticket(
            id: _nid(),
            number: ++_ticketNum,
            epicId: 'e1',
            title: 'Añadir verificación 2FA por SMS como alternativa',
            description:
                'Ofrecer SMS como segundo factor alternativo al TOTP para usuarios sin smartphone.',
            priority: TicketPriority.medium,
            assigneeId: 'u3',
            createdById: 'u2',
            dueDate: DateTime.now().add(const Duration(days: 6)),
            subtasks: [
              Subtask(id: _nid(), title: 'Integración con proveedor SMS')
            ],
            events: [
              TicketEvent(type: 'CREATED', userId: 'u2', ts: DateTime.now()),
              TicketEvent(
                  type: 'ASSIGNED',
                  userId: 'u2',
                  toUserId: 'u3',
                  ts: DateTime.now()),
            ],
          );
          _tickets.add(t);
          _notify(['u3'], NotificationKind.assignment,
              'Luis Vega te asignó: “${t.title}”',
              ticketId: t.id);
          _notify(['u1'], NotificationKind.system,
              'Luis Vega creó un ticket en Portal Clientes: “${t.title}”',
              ticketId: t.id);
        }
      case 2:
        {
          // Marco completa el mapa en vivo
          final t = _ticket('t8');
          if (t.status != TicketStatus.done) {
            _settleTimer(t);
            t.status = TicketStatus.done;
            t.prLink = 'https://github.com/wellq/logistica/pull/238';
            t.events.add(TicketEvent(
                type: 'COMPLETED', userId: 'u5', ts: DateTime.now()));
            _notify(_leadIds, NotificationKind.completion,
                'Marco Ibáñez completó un ticket en App Logística: “${t.title}”',
                ticketId: t.id);
          }
        }
      case 3:
        {
          // Sofía plantea una pregunta en el matching SEPA
          final t = _ticket('t5');
          if (t.status == TicketStatus.inProgress) {
            _settleTimer(t);
            t.status = TicketStatus.blocked;
            t.events.add(TicketEvent(
                type: 'QUESTION',
                userId: 'u4',
                text:
                    '¿La tolerancia de ±0,01 € aplica también a pagos agrupados de varias facturas?',
                ts: DateTime.now()));
            _notify(_leadIds, NotificationKind.question,
                'Sofía Márquez planteó una pregunta en API Pagos: “${t.title}”',
                ticketId: t.id);
          }
        }
      default:
        return; // guion agotado: no más eventos
    }
    _simStep++;
    _emitChange();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _changes.close();
    _push.close();
  }
}
