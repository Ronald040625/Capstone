/// Repositorio contra el backend FastAPI de CoreStream.
///
/// Usa los endpoints existentes más el paquete `mobile_api`:
///   POST /auth/login · POST /auth/logout
///   GET  /mobile/dashboard · /mobile/applications/{id}/board
///   GET  /mobile/tickets/{id}/detail · /mobile/team/workload
///   POST /tickets/{id}/assign|start|complete|question|resolve-question|redirect
///   PUT  /subtasks/{id} · POST /tickets/
///   GET  /incidents/... · GET/POST /notifications/...
///   POST /devices/  (token FCM)
///
/// Las notificaciones en tiempo real llegan por el WebSocket autenticado
/// `/ws/mobile/notifications?token=` (reconexión con backoff simple).
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';
import 'repository.dart';

class ApiRepository implements CoreStreamRepository {
  ApiRepository(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
    ));
  }

  final Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  User? _current;
  WebSocketChannel? _ws;
  bool _wsShouldRun = false;

  final _changes = StreamController<int>.broadcast();
  final _push = StreamController<AppNotification>.broadcast();
  int _rev = 0;

  final Map<String, User> _userCache = {};
  final Map<String, Project> _projectByTicket = {};

  void _bump() => _changes.add(++_rev);

  static const _palette = [
    Color(0xFF4C8DFF),
    Color(0xFF8B7CF6),
    Color(0xFF2FBF71),
    Color(0xFFF2A93B),
    Color(0xFFF0554E),
    Color(0xFF31B3C2),
  ];

  User _parseUser(Map<String, dynamic> j) {
    final id = j['id'].toString();
    final user = User(
      id: id,
      fullName: (j['full_name'] ?? j['fullName'] ?? '¿?') as String,
      role: UserRoleWire.parse((j['role'] ?? 'DEVELOPER') as String),
      specialty: j['specialty'] as String?,
      avatarColor: _palette[id.hashCode.abs() % _palette.length],
      isActive: (j['is_active'] ?? true) as bool,
    );
    _userCache[id] = user;
    return user;
  }

  Ticket _parseTicketSummary(Map<String, dynamic> j, String epicId) {
    final assignee = j['assignee'];
    if (assignee is Map<String, dynamic>) _parseUser(assignee);
    return Ticket(
      id: j['id'].toString(),
      number: (j['number'] ?? 0) as int,
      epicId: epicId,
      title: j['title'] as String,
      description: (j['description'] ?? '') as String,
      status: TicketStatusWire.parse((j['status'] ?? 'TODO') as String),
      priority: TicketPriorityWire.parse((j['priority'] ?? 'MEDIUM') as String),
      assigneeId: assignee is Map
          ? assignee['id']?.toString()
          : j['assignee_id']?.toString(),
      dueDate: j['due_date'] != null
          ? DateTime.tryParse(j['due_date'] as String)
          : null,
      subtasks: [
        for (var k = 0; k < ((j['subtasks_done'] ?? 0) as int); k++)
          Subtask(id: 'done-$k', title: '', done: true),
        for (var k = 0;
            k <
                (((j['subtasks_total'] ?? 0) as int) -
                    ((j['subtasks_done'] ?? 0) as int));
            k++)
          Subtask(id: 'todo-$k', title: ''),
      ],
    );
  }

  // ------------------------------------------------------------- sesión

  @override
  Future<List<User>> loginOptions() async {
    // En modo API el login real es email/contraseña; para la demo comercial
    // se listan los usuarios activos y se pide la contraseña al elegir.
    final r = await _dio.get('/users/');
    return [
      for (final j in r.data as List) _parseUser(j as Map<String, dynamic>)
    ];
  }

  @override
  Future<User> login(User user) async {
    final r = await _dio.post('/auth/demo-login', data: {'user_id': user.id});
    _accessToken = r.data['access_token'] as String?;
    _refreshToken = r.data['refresh_token'] as String?;
    final rawUser = r.data['user'];
    _current = rawUser is Map<String, dynamic> ? _parseUser(rawUser) : user;
    _connectWebSocket();
    return _current!;
  }

  Future<User> loginWithCredentials(String email, String password) async {
    final r = await _dio
        .post('/auth/login', data: {'email': email, 'password': password});
    _accessToken = r.data['access_token'] as String?;
    _refreshToken = r.data['refresh_token'] as String?;
    final me = await _dio.get('/auth/me');
    _current = _parseUser(me.data as Map<String, dynamic>);
    _connectWebSocket();
    return _current!;
  }

  @override
  Future<void> logout() async {
    _wsShouldRun = false;
    await _ws?.sink.close();
    if (_refreshToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': _refreshToken});
      } catch (_) {/* el logout local no debe fallar por red */}
    }
    _accessToken = null;
    _refreshToken = null;
    _current = null;
  }

  @override
  Future<void> registerDevice(String fcmToken, String platform) async {
    await _dio
        .post('/devices/', data: {'fcm_token': fcmToken, 'platform': platform});
  }

  // ------------------------------------------------------ websocket (push)

  Future<void> _connectWebSocket() async {
    _wsShouldRun = true;
    final base = _dio.options.baseUrl.replaceFirst('http', 'ws');
    var delay = const Duration(seconds: 2);
    while (_wsShouldRun) {
      try {
        _ws = WebSocketChannel.connect(
          Uri.parse('$base/ws/mobile/notifications?token=$_accessToken'),
        );
        await _ws!.ready;
        delay = const Duration(seconds: 2);
        await for (final raw in _ws!.stream) {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'ping') continue;
          final n = AppNotification(
            id: (data['id'] ?? '${DateTime.now().microsecondsSinceEpoch}')
                .toString(),
            kind: NotificationKindWire.parse(
                (data['type'] ?? 'SYSTEM') as String),
            message: (data['message'] ?? data['title'] ?? '') as String,
            ts: DateTime.tryParse((data['created_at'] ?? '') as String) ??
                DateTime.now(),
            ticketId: data['ticket_id']?.toString(),
            incidentId: data['incident_id']?.toString(),
          );
          _push.add(n);
          _bump();
        }
      } catch (_) {
        // reintento con backoff limitado
      }
      if (!_wsShouldRun) break;
      await Future<void>.delayed(delay);
      if (delay < const Duration(seconds: 30)) delay *= 2;
    }
  }

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Stream<AppNotification> get incomingPush => _push.stream;

  // ------------------------------------------------------------- lecturas

  @override
  Future<Dashboard> fetchDashboard() async {
    final r = await _dio.get('/mobile/dashboard');
    final j = r.data as Map<String, dynamic>;
    final role = UserRoleWire.parse(j['role'] as String);
    final stats = (j['stats'] as Map).cast<String, num>();

    if (role != UserRole.developer) {
      return Dashboard(
        role: role,
        stats: {
          'apps': (stats['applications'] ?? 0).toInt(),
          'open': (stats['open_tickets'] ?? 0).toInt(),
          'blocked': (stats['blocked_tickets'] ?? 0).toInt(),
          'late': (stats['overdue_tickets'] ?? 0).toInt(),
        },
        projects: [
          for (final p in (j['projects'] ?? []) as List)
            ProjectSummary(
              project: Project(
                id: p['id'].toString(),
                name: p['name'] as String,
                code: _codeOf(p['name'] as String),
                color: _palette[
                    p['id'].toString().hashCode.abs() % _palette.length],
              ),
              epicsCount: (p['epics_count'] ?? 0) as int,
              ticketsTotal: (p['tickets_total'] ?? 0) as int,
              ticketsDone: (p['tickets_done'] ?? 0) as int,
              overdue: (p['overdue'] ?? 0) as int,
            ),
        ],
        attention: [
          for (final a in (j['attention'] ?? []) as List)
            if (a['kind'] == 'TICKET')
              AttentionItem.ticket(
                Ticket(
                  id: a['id'].toString(),
                  number: 0,
                  epicId: '',
                  title: a['title'] as String,
                  description: '',
                  status:
                      TicketStatusWire.parse((a['status'] ?? 'TODO') as String),
                  dueDate: a['due_date'] != null
                      ? DateTime.tryParse(a['due_date'] as String)
                      : null,
                ),
                (a['app_name'] ?? '') as String,
              )
            else
              AttentionItem.incident(
                Incident(
                  id: a['id'].toString(),
                  number: 0,
                  projectId: '',
                  title: a['title'] as String,
                  description: '',
                  category: IncidentCategory.criticalError,
                  severity: IncidentSeverityWire.parse(
                      (a['severity'] ?? 'MEDIUM') as String),
                  status: IncidentStatusWire.parse(
                      (a['status'] ?? 'OPEN') as String),
                  reporterId: '',
                  createdAt: DateTime.now(),
                ),
                (a['app_name'] ?? '') as String,
              ),
        ],
      );
    }

    return Dashboard(
      role: role,
      stats: {
        'mine': (stats['my_open'] ?? 0).toInt(),
        'prog': (stats['in_progress'] ?? 0).toInt(),
        'doneWeek': (stats['done_last_7d'] ?? 0).toInt(),
        'incidents': (stats['my_open_incidents'] ?? 0).toInt(),
      },
      myTickets: [
        for (final t in (j['my_tickets'] ?? []) as List)
          _parseTicketSummary(t as Map<String, dynamic>, ''),
      ],
      myIncidents: [
        for (final i in (j['my_incidents'] ?? []) as List)
          Incident(
            id: i['id'].toString(),
            number: 0,
            projectId: '',
            title: i['title'] as String,
            description: '',
            category: IncidentCategory.criticalError,
            severity: IncidentSeverityWire.parse(
                (i['severity'] ?? 'MEDIUM') as String),
            status: IncidentStatusWire.parse((i['status'] ?? 'OPEN') as String),
            reporterId: '',
            createdAt: DateTime.tryParse((i['created_at'] ?? '') as String) ??
                DateTime.now(),
          ),
      ],
    );
  }

  String _codeOf(String name) {
    final parts = name.split(RegExp(r'\s+'));
    return parts.length > 1
        ? (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase()
        : name.substring(0, 2).toUpperCase();
  }

  @override
  Future<List<ProjectSummary>> fetchProjects() async {
    final r = await _dio.get('/mobile/applications');
    return [
      for (final p in r.data as List)
        ProjectSummary(
          project: Project(
            id: p['id'].toString(),
            name: p['name'] as String,
            code: _codeOf(p['name'] as String),
            color:
                _palette[p['id'].toString().hashCode.abs() % _palette.length],
          ),
          epicsCount: (p['epics_count'] ?? 0) as int,
          ticketsTotal: (p['tickets_total'] ?? 0) as int,
          ticketsDone: (p['tickets_done'] ?? 0) as int,
          overdue: (p['overdue'] ?? 0) as int,
        ),
    ];
  }

  @override
  Future<Board> fetchBoard(String projectId) async {
    final r = await _dio.get('/mobile/applications/$projectId/board');
    final j = r.data as Map<String, dynamic>;
    final app = j['application'] as Map<String, dynamic>;
    final project = Project(
      id: app['id'].toString(),
      name: app['name'] as String,
      code: _codeOf(app['name'] as String),
      color: _palette[app['id'].toString().hashCode.abs() % _palette.length],
    );
    final epics = <EpicBoard>[];
    for (final e in (j['epics'] ?? []) as List) {
      final epic = Epic(
        id: e['id'].toString(),
        projectId: project.id,
        name: e['name'] as String,
        orderIndex: (e['order_index'] ?? 0) as int,
      );
      final tickets = [
        for (final t in (e['tickets'] ?? []) as List)
          _parseTicketSummary(t as Map<String, dynamic>, epic.id),
      ];
      for (final t in tickets) {
        _projectByTicket[t.id] = project;
      }
      epics.add(EpicBoard(epic: epic, tickets: tickets));
    }
    return Board(project: project, epics: epics);
  }

  @override
  Future<TicketDetail> fetchTicketDetail(String ticketId) async {
    final r = await _dio.get('/mobile/tickets/$ticketId/detail');
    final j = r.data as Map<String, dynamic>;
    final tj = j['ticket'] as Map<String, dynamic>;
    final timer = (j['timer'] ?? const {}) as Map<String, dynamic>;
    final perms = (j['permissions'] ?? const {}) as Map<String, dynamic>;

    final ticket = Ticket(
      id: tj['id'].toString(),
      number: (tj['number'] ?? 0) as int,
      epicId: j['epic']['id'].toString(),
      title: tj['title'] as String,
      description: (tj['description'] ?? '') as String,
      status: TicketStatusWire.parse((tj['status'] ?? 'TODO') as String),
      priority:
          TicketPriorityWire.parse((tj['priority'] ?? 'MEDIUM') as String),
      assigneeId: j['assignee'] != null ? j['assignee']['id'].toString() : null,
      createdById:
          j['created_by'] != null ? j['created_by']['id'].toString() : null,
      dueDate: tj['due_date'] != null
          ? DateTime.tryParse(tj['due_date'] as String)
          : null,
      spentSeconds:
          (timer['time_spent_seconds'] ?? tj['time_spent_seconds'] ?? 0) as int,
      blockedSeconds: (timer['blocked_time_seconds'] ??
          tj['blocked_time_seconds'] ??
          0) as int,
      runningSince:
          (timer['is_running'] ?? false) as bool ? DateTime.now() : null,
      prLink: tj['pr_link'] as String?,
      subtasks: [
        for (final s in (j['subtasks'] ?? []) as List)
          Subtask(
            id: s['id'].toString(),
            title: (s['title'] ?? '') as String,
            done: (s['is_completed'] ?? false) as bool,
          ),
      ],
      events: [
        for (final e in (j['events'] ?? []) as List)
          TicketEvent(
            type: _mapEventType((e['event_type'] ?? '') as String),
            userId: e['user'] != null ? e['user']['id'].toString() : '',
            ts: DateTime.tryParse((e['created_at'] ?? '') as String) ??
                DateTime.now(),
            text: e['payload'] is Map
                ? (e['payload']['comment'] ?? e['payload']['question_text'])
                    ?.toString()
                : null,
          ),
      ],
    );

    if (j['assignee'] != null) {
      _parseUser(j['assignee'] as Map<String, dynamic>);
    }
    if (j['created_by'] != null) {
      _parseUser(j['created_by'] as Map<String, dynamic>);
    }
    final project = Project(
      id: j['application']['id'].toString(),
      name: j['application']['name'] as String,
      code: _codeOf(j['application']['name'] as String),
      color: _palette[
          j['application']['id'].toString().hashCode.abs() % _palette.length],
    );
    _projectByTicket[ticket.id] = project;

    return TicketDetail(
      ticket: ticket,
      epic: Epic(
          id: j['epic']['id'].toString(),
          projectId: project.id,
          name: j['epic']['name'] as String),
      project: project,
      assignee: userById(ticket.assigneeId),
      createdBy: userById(ticket.createdById),
      permissions: TicketPermissions(
        canAssign: (perms['can_assign'] ?? false) as bool,
        canStart: (perms['can_start'] ?? false) as bool,
        canComplete: (perms['can_complete'] ?? false) as bool,
        canQuestion: (perms['can_question'] ?? false) as bool,
        canResolveQuestion: (perms['can_resolve_question'] ?? false) as bool,
        canRedirect: (perms['can_redirect'] ?? false) as bool,
        canEditSubtasks: (perms['can_edit_subtasks'] ?? false) as bool,
        canEdit: (perms['can_edit'] ?? false) as bool,
        canDelete: (perms['can_delete'] ?? false) as bool,
      ),
    );
  }

  String _mapEventType(String wire) => switch (wire) {
        'STATUS_CHANGED' => 'STATUS',
        'QUESTION_RAISED' => 'QUESTION',
        'QUESTION_RESOLVED' => 'RESOLVED',
        _ => wire,
      };

  @override
  Future<List<Incident>> fetchIncidents() async {
    final me = _current;
    final path =
        (me != null && !me.isLead) ? '/incidents/my-incidents' : '/incidents/';
    final r = await _dio.get(path);
    final list = (r.data is Map
        ? r.data['items'] ?? r.data['incidents'] ?? []
        : r.data) as List;
    return [for (final j in list) _parseIncident(j as Map<String, dynamic>)];
  }

  Incident _parseIncident(Map<String, dynamic> j) {
    final comments = <IncidentComment>[];
    for (final raw in (j['comments'] as List? ?? const [])) {
      final comment = raw as Map<String, dynamic>;
      final user = comment['user'] ?? comment['author'];
      if (user is Map<String, dynamic>) _parseUser(user);
      comments.add(IncidentComment(
        userId: (comment['user_id'] ??
                comment['author_id'] ??
                (user is Map ? user['id'] : null) ??
                '')
            .toString(),
        text:
            (comment['text'] ?? comment['comment'] ?? comment['content'] ?? '')
                .toString(),
        ts: DateTime.tryParse(
              (comment['created_at'] ?? comment['timestamp'] ?? '').toString(),
            ) ??
            DateTime.now(),
      ));
    }
    comments.sort((a, b) => a.ts.compareTo(b.ts));

    return Incident(
      id: j['id'].toString(),
      number: (j['number'] ?? 0) as int,
      projectId: (j['application_id'] ?? '').toString(),
      title: j['title'] as String,
      description: (j['description'] ?? '') as String,
      category: IncidentCategoryWire.parse(
          (j['category'] ?? 'NON_CRITICAL_ERROR') as String),
      severity:
          IncidentSeverityWire.parse((j['severity'] ?? 'MEDIUM') as String),
      status: IncidentStatusWire.parse((j['status'] ?? 'OPEN') as String),
      reporterId: (j['reporter_id'] ?? '').toString(),
      assigneeId: j['assignee_id']?.toString(),
      createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
          DateTime.now(),
      comments: comments,
    );
  }

  @override
  Future<Incident> fetchIncident(String incidentId) async {
    final r = await _dio.get('/incidents/$incidentId');
    return _parseIncident(r.data as Map<String, dynamic>);
  }

  @override
  Future<List<MemberLoad>> fetchTeamWorkload() async {
    final r = await _dio.get('/mobile/team/workload');
    return [
      for (final m in r.data as List)
        MemberLoad(
          user: _parseUser(m['user'] as Map<String, dynamic>),
          activeTickets: (m['active_tickets'] ?? 0) as int,
          inProgress: (m['in_progress'] ?? 0) as int,
          blocked: (m['blocked'] ?? 0) as int,
          doneLast7d: (m['done_last_7d'] ?? 0) as int,
          openIncidents: (m['open_incidents'] ?? 0) as int,
        ),
    ];
  }

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final r = await _dio.get('/notifications/', queryParameters: {'limit': 50});
    return [
      for (final j in r.data as List)
        AppNotification(
          id: j['id'].toString(),
          kind: NotificationKindWire.parse((j['type'] ?? 'SYSTEM') as String),
          message: (j['message'] ?? j['title'] ?? '') as String,
          ts: DateTime.tryParse((j['created_at'] ?? '') as String) ??
              DateTime.now(),
          read: (j['is_read'] ?? false) as bool,
          ticketId: j['ticket_id']?.toString(),
          incidentId: j['incident_id']?.toString(),
        ),
    ];
  }

  @override
  Future<int> unreadCount() async {
    final r = await _dio.get('/notifications/unread-count');
    final d = r.data;
    if (d is int) return d;
    if (d is Map) return (d['count'] ?? d['unread'] ?? 0) as int;
    return 0;
  }

  @override
  Future<List<User>> fetchUsers() async {
    final r = await _dio.get('/users/');
    return [
      for (final j in r.data as List) _parseUser(j as Map<String, dynamic>)
    ];
  }

  @override
  User? userById(String? id) => id == null ? null : _userCache[id];

  @override
  Project? projectOfTicket(Ticket t) => _projectByTicket[t.id];

  // ------------------------------------------------------------- acciones

  Future<void> _act(Future<void> Function() call) async {
    await call();
    _bump();
  }

  @override
  Future<void> assignTicket(String ticketId, String assigneeId,
          {String? comment}) =>
      _act(() => _dio.post('/tickets/$ticketId/assign', data: {
            'assignee_id': assigneeId,
            if (comment != null) 'comment': comment
          }));

  @override
  Future<void> startTicket(String ticketId) =>
      _act(() => _dio.post('/tickets/$ticketId/start'));

  @override
  Future<void> completeTicket(String ticketId, String prLink) => _act(() =>
      _dio.post('/tickets/$ticketId/complete', data: {'pr_link': prLink}));

  @override
  Future<void> raiseQuestion(String ticketId, String question) =>
      _act(() => _dio.post('/tickets/$ticketId/question',
          data: {'question_text': question}));

  @override
  Future<void> resolveQuestion(String ticketId, String resolution) =>
      _act(() => _dio.post('/tickets/$ticketId/resolve-question',
          data: {'resolution_text': resolution}));

  @override
  Future<void> redirectTicket(
          String ticketId, String toUserId, String reason) =>
      _act(() => _dio.post('/tickets/$ticketId/redirect',
          data: {'to_user_id': toUserId, 'reason': reason}));

  @override
  Future<void> toggleSubtask(String ticketId, String subtaskId, bool done) =>
      _act(
          () => _dio.put('/subtasks/$subtaskId', data: {'is_completed': done}));

  @override
  Future<void> createTicket({
    required String epicId,
    required String title,
    required TicketPriority priority,
    String? assigneeId,
  }) =>
      _act(() => _dio.post('/tickets/', data: {
            'title': title,
            'epic_id': epicId,
            'priority': priority.wire,
            if (assigneeId != null) 'assignee_id': assigneeId,
          }));

  @override
  Future<void> takeIncident(String incidentId) =>
      _act(() => _dio.post('/incidents/$incidentId/start'));

  @override
  Future<void> assignIncident(String incidentId, String assigneeId) =>
      _act(() => _dio.post('/incidents/$incidentId/assign',
          data: {'assignee_id': assigneeId}));

  @override
  Future<void> setIncidentStatus(String incidentId, IncidentStatus status) {
    final action = switch (status) {
      IncidentStatus.underReview => 'review',
      IncidentStatus.resolved => 'resolve',
      IncidentStatus.closed => 'close',
      IncidentStatus.reopened => 'reopen',
      IncidentStatus.inProgress => 'start',
      IncidentStatus.open => 'reopen',
    };
    return _act(() => _dio.post('/incidents/$incidentId/$action'));
  }

  @override
  Future<void> commentIncident(String incidentId, String comment) =>
      _act(() => _dio.post('/incidents/$incidentId/comments',
          data: {'content': comment.trim()}));

  @override
  Future<void> markNotificationRead(String id) =>
      _act(() => _dio.post('/notifications/mark-read', data: {
            'notification_ids': [id]
          }));

  @override
  Future<void> markAllNotificationsRead() =>
      _act(() => _dio.post('/notifications/mark-all-read'));

  @override
  void dispose() {
    _wsShouldRun = false;
    _ws?.sink.close();
    _changes.close();
    _push.close();
  }
}
