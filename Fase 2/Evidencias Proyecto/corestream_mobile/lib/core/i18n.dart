/// Internacionalización ligera ES/EN sin dependencias externas.
///
/// El idioma activo vive en un provider (localeProvider); los widgets
/// obtienen textos con `S.of(ref)` o `S.byCode('es')`.
library;

class S {
  const S(this._m);

  final Map<String, String> _m;

  String call(String key) => _m[key] ?? _es[key] ?? key;

  static S byCode(String code) => S(code == 'en' ? _en : _es);

  static const supported = ['es', 'en'];

  static const Map<String, String> _es = {
    'app_name': 'CoreStream',
    'login_sub':
        'Selecciona un usuario demo para entrar. La app adapta la navegación y los permisos según el rol, igual que la versión web.',
    'demo_note': 'Datos de demostración — ningún cambio se guarda.',
    'api_mode': 'Conectado al servidor',
    'role_ADMIN': 'Administrador',
    'role_GROUP_LEADER': 'Líder de grupo',
    'role_DEVELOPER': 'Desarrollador',
    'tab_home': 'Inicio',
    'tab_work': 'Mi trabajo',
    'tab_projects': 'Proyectos',
    'tab_incidents': 'Incidencias',
    'tab_team': 'Equipo',
    'hello': 'Hola',
    'home_sub_admin': 'Estado global de los proyectos',
    'home_sub_dev': 'Tu trabajo de hoy',
    'st_apps': 'Aplicaciones',
    'st_open': 'Tickets abiertos',
    'st_blocked': 'Bloqueados',
    'st_late': 'Atrasados',
    'st_mine': 'Mis tickets',
    'st_prog': 'En progreso',
    'st_done_week': 'Hechos (semana)',
    'my_incidents': 'Mis incidencias',
    'proj_status': 'Estado de proyectos',
    'attention': 'Requiere atención',
    'all_clear': 'Todo en orden: nada requiere atención.',
    'epics': 'épicas',
    'tickets': 'tickets',
    'pending': 'pendientes',
    'overdue': 'atrasados',
    'of': 'de',
    's_TODO': 'Por hacer',
    's_IN_PROGRESS': 'En progreso',
    's_BLOCKED': 'Bloqueado',
    's_REDIRECTED': 'Redirigido',
    's_DONE': 'Hecho',
    'p_LOW': 'Baja',
    'p_MEDIUM': 'Media',
    'p_HIGH': 'Alta',
    'p_URGENT': 'Urgente',
    'is_OPEN': 'Abierta',
    'is_IN_PROGRESS': 'En progreso',
    'is_UNDER_REVIEW': 'En revisión',
    'is_RESOLVED': 'Resuelta',
    'is_CLOSED': 'Cerrada',
    'is_REOPENED': 'Reabierta',
    'sev_CRITICAL': 'Crítica',
    'sev_HIGH': 'Alta',
    'sev_MEDIUM': 'Media',
    'sev_LOW': 'Baja',
    'cat_NEW_FEATURE': 'Nueva funcionalidad',
    'cat_CRITICAL_ERROR': 'Error crítico',
    'cat_NON_CRITICAL_ERROR': 'Error no crítico',
    'cat_USABILITY_ISSUE': 'Usabilidad',
    'assignee': 'Asignado a',
    'unassigned': 'Sin asignar',
    'due': 'Vence',
    'time_spent': 'Tiempo invertido',
    'time_blocked': 'Tiempo bloqueado',
    'description': 'Descripción',
    'subtasks': 'Subtareas',
    'activity': 'Registro de actividad',
    'assign': 'Asignar',
    'reassign': 'Reasignar',
    'assign_sub':
        'Elige a quién asignar esta tarea. Recibirá una notificación al instante.',
    'start': 'Comenzar a trabajar',
    'complete': 'Completar',
    'raise_q': 'Plantear pregunta',
    'redirect': 'Redirigir',
    'resume': 'Reanudar trabajo',
    'complete_sub': 'Pega el enlace del Pull Request para cerrar el ticket.',
    'pr_link': 'Enlace de PR',
    'pr_invalid': 'Enlace inválido. Se admite GitHub, GitLab o Bitbucket.',
    'q_sub':
        'El ticket quedará bloqueado y se pausará el temporizador hasta que el líder responda.',
    'q_ph': '¿Qué impide avanzar? (mín. 10 caracteres)',
    'q_short': 'Escribe al menos 10 caracteres.',
    'rd_sub':
        'El ticket pasará a otra persona del equipo con una razón visible en el historial.',
    'rd_reason': 'Razón (mín. 10 caracteres)',
    'rs_sub':
        'Describe cómo se resolvió el bloqueo para reanudar el temporizador.',
    'send': 'Enviar',
    'cancel': 'Cancelar',
    'confirm': 'Confirmar',
    'save': 'Guardar',
    'new_ticket': 'Nuevo ticket',
    'nt_sub': 'Se creará en esta épica y se notificará al equipo.',
    'nt_title': 'Título del ticket',
    'nt_short': 'Escribe al menos 5 caracteres.',
    'priority': 'Prioridad',
    'optional': 'opcional',
    'view_only': 'Solo lectura — tu rol no permite editar este ticket.',
    'blocked_waiting': 'Esperando respuesta del líder',
    'incident': 'Incidencia',
    'reported_by': 'Reportada por',
    'severity': 'Severidad',
    'take': 'Tomar incidencia',
    'to_review': 'Pasar a revisión',
    'resolve_inc': 'Marcar resuelta',
    'close_inc': 'Cerrar',
    'reopen': 'Reabrir',
    'comments': 'Comentarios',
    'add_comment': 'Agregar comentario',
    'comment_hint': 'Escribe un comentario',
    'workload': 'Carga de trabajo',
    'active_t': 'activos',
    'active_tickets': 'Tickets activos',
    'open_incidents': 'Incidencias abiertas',
    'notifications': 'Notificaciones',
    'mark_all': 'Marcar todas como leídas',
    'no_notifs':
        'Sin notificaciones nuevas.\nCuando ocurra algo en tus proyectos, aparecerá aquí.',
    'no_tickets': 'No hay tickets con este filtro.',
    'settings': 'Ajustes',
    'theme': 'Tema',
    'dark': 'Oscuro',
    'light': 'Claro',
    'language': 'Idioma',
    'logout': 'Cerrar sesión',
    'push_demo': 'Notificaciones simuladas',
    'push_demo_sub': 'Genera eventos del equipo cada ~20 s',
    'now': 'ahora',
    'min_ago': 'hace {n} min',
    'h_ago': 'hace {n} h',
    'd_ago': 'hace {n} d',
    'n_ASSIGNMENT': 'Ticket asignado',
    'n_QUESTION': 'Pregunta planteada',
    'n_REDIRECT': 'Ticket redirigido',
    'n_COMPLETION': 'Ticket completado',
    'n_SYSTEM': 'Nuevo ticket',
    'n_INCIDENT': 'Nueva incidencia',
    'all': 'Todos',
    'f_mine': 'Míos',
    'error_generic': 'Algo salió mal. Desliza para reintentar.',
    'assigned_you': 'te asignó',
    'ev_created': 'creó el ticket',
    'ev_assigned_to': 'asignó el ticket a',
    'ev_resolved': 'resolvió el bloqueo',
    'ev_redirected_to': 'redirigió el ticket a',
  };

  static const Map<String, String> _en = {
    'app_name': 'CoreStream',
    'login_sub':
        'Pick a demo user to sign in. The app adapts navigation and permissions to the role, just like the web version.',
    'demo_note': 'Demo data — nothing is saved.',
    'api_mode': 'Connected to server',
    'role_ADMIN': 'Administrator',
    'role_GROUP_LEADER': 'Group leader',
    'role_DEVELOPER': 'Developer',
    'tab_home': 'Home',
    'tab_work': 'My work',
    'tab_projects': 'Projects',
    'tab_incidents': 'Incidents',
    'tab_team': 'Team',
    'hello': 'Hi',
    'home_sub_admin': 'Global project status',
    'home_sub_dev': 'Your work today',
    'st_apps': 'Applications',
    'st_open': 'Open tickets',
    'st_blocked': 'Blocked',
    'st_late': 'Overdue',
    'st_mine': 'My tickets',
    'st_prog': 'In progress',
    'st_done_week': 'Done (week)',
    'my_incidents': 'My incidents',
    'proj_status': 'Project status',
    'attention': 'Needs attention',
    'all_clear': 'All clear: nothing needs attention.',
    'epics': 'epics',
    'tickets': 'tickets',
    'pending': 'pending',
    'overdue': 'overdue',
    'of': 'of',
    's_TODO': 'To do',
    's_IN_PROGRESS': 'In progress',
    's_BLOCKED': 'Blocked',
    's_REDIRECTED': 'Redirected',
    's_DONE': 'Done',
    'p_LOW': 'Low',
    'p_MEDIUM': 'Medium',
    'p_HIGH': 'High',
    'p_URGENT': 'Urgent',
    'is_OPEN': 'Open',
    'is_IN_PROGRESS': 'In progress',
    'is_UNDER_REVIEW': 'Under review',
    'is_RESOLVED': 'Resolved',
    'is_CLOSED': 'Closed',
    'is_REOPENED': 'Reopened',
    'sev_CRITICAL': 'Critical',
    'sev_HIGH': 'High',
    'sev_MEDIUM': 'Medium',
    'sev_LOW': 'Low',
    'cat_NEW_FEATURE': 'New feature',
    'cat_CRITICAL_ERROR': 'Critical error',
    'cat_NON_CRITICAL_ERROR': 'Non-critical error',
    'cat_USABILITY_ISSUE': 'Usability',
    'assignee': 'Assignee',
    'unassigned': 'Unassigned',
    'due': 'Due',
    'time_spent': 'Time spent',
    'time_blocked': 'Blocked time',
    'description': 'Description',
    'subtasks': 'Subtasks',
    'activity': 'Activity log',
    'assign': 'Assign',
    'reassign': 'Reassign',
    'assign_sub':
        "Choose who takes this task. They'll get an instant notification.",
    'start': 'Start working',
    'complete': 'Complete',
    'raise_q': 'Raise question',
    'redirect': 'Redirect',
    'resume': 'Resume work',
    'complete_sub': 'Paste the Pull Request link to close the ticket.',
    'pr_link': 'PR link',
    'pr_invalid': 'Invalid link. GitHub, GitLab or Bitbucket supported.',
    'q_sub':
        'The ticket will be blocked and the timer paused until the leader answers.',
    'q_ph': "What's blocking you? (min. 10 characters)",
    'q_short': 'Write at least 10 characters.',
    'rd_sub':
        'The ticket moves to another teammate with a reason visible in the history.',
    'rd_reason': 'Reason (min. 10 characters)',
    'rs_sub': 'Describe how the blocker was resolved to resume the timer.',
    'send': 'Send',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'save': 'Save',
    'new_ticket': 'New ticket',
    'nt_sub': 'It will be created in this epic and the team will be notified.',
    'nt_title': 'Ticket title',
    'nt_short': 'Write at least 5 characters.',
    'priority': 'Priority',
    'optional': 'optional',
    'view_only': "Read-only — your role can't edit this ticket.",
    'blocked_waiting': "Waiting for leader's answer",
    'incident': 'Incident',
    'reported_by': 'Reported by',
    'severity': 'Severity',
    'take': 'Take incident',
    'to_review': 'Send to review',
    'resolve_inc': 'Mark resolved',
    'close_inc': 'Close',
    'reopen': 'Reopen',
    'comments': 'Comments',
    'add_comment': 'Add comment',
    'comment_hint': 'Write a comment',
    'workload': 'Workload',
    'active_t': 'active',
    'active_tickets': 'Active tickets',
    'open_incidents': 'Open incidents',
    'notifications': 'Notifications',
    'mark_all': 'Mark all as read',
    'no_notifs':
        'No new notifications.\nWhen something happens in your projects, it shows up here.',
    'no_tickets': 'No tickets match this filter.',
    'settings': 'Settings',
    'theme': 'Theme',
    'dark': 'Dark',
    'light': 'Light',
    'language': 'Language',
    'logout': 'Sign out',
    'push_demo': 'Simulated notifications',
    'push_demo_sub': 'Generates team events every ~20 s',
    'now': 'now',
    'min_ago': '{n} min ago',
    'h_ago': '{n} h ago',
    'd_ago': '{n} d ago',
    'n_ASSIGNMENT': 'Ticket assigned',
    'n_QUESTION': 'Question raised',
    'n_REDIRECT': 'Ticket redirected',
    'n_COMPLETION': 'Ticket completed',
    'n_SYSTEM': 'New ticket',
    'n_INCIDENT': 'New incident',
    'all': 'All',
    'f_mine': 'Mine',
    'error_generic': 'Something went wrong. Pull to retry.',
    'assigned_you': 'assigned you',
    'ev_created': 'created the ticket',
    'ev_assigned_to': 'assigned the ticket to',
    'ev_resolved': 'resolved the blocker',
    'ev_redirected_to': 'redirected the ticket to',
  };
}

/// Tiempo relativo localizado ("hace 5 min" / "5 min ago").
String relativeTime(S s, DateTime ts) {
  final d = DateTime.now().difference(ts);
  if (d.inSeconds < 90) return s('now');
  if (d.inMinutes < 60) {
    return s('min_ago').replaceFirst('{n}', '${d.inMinutes}');
  }
  if (d.inHours < 24) return s('h_ago').replaceFirst('{n}', '${d.inHours}');
  return s('d_ago').replaceFirst('{n}', '${d.inDays}');
}

/// Fecha corta localizada ("29 ago" / "29 Aug").
String shortDate(String lang, DateTime d) {
  const es = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic'
  ];
  const en = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final m = (lang == 'en' ? en : es)[d.month - 1];
  return '${d.day} $m';
}

/// Duración "4 h 22 m" / "35 min".
String fmtDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} m';
  return '$m min';
}

/// Temporizador "04:22:07".
String fmtTimer(int seconds) {
  final h = (seconds ~/ 3600).toString().padLeft(2, '0');
  final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
