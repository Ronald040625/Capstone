// Tests del repositorio demo: flujos de asignación, completado con PR,
// preguntas/bloqueos y notificaciones generadas.

import 'package:flutter_test/flutter_test.dart';

import 'package:corestream_mobile/data/demo_repository.dart';
import 'package:corestream_mobile/models/models.dart';

void main() {
  late DemoRepository repo;
  late User admin;
  late User leader;
  late User dev;

  setUp(() async {
    repo = DemoRepository()..simulationEnabled = false;
    final users = await repo.loginOptions();
    admin = users.firstWhere((u) => u.role == UserRole.admin);
    leader = users.firstWhere((u) => u.role == UserRole.groupLeader);
    dev = users.firstWhere((u) => u.role == UserRole.developer);
  });

  tearDown(() => repo.dispose());

  test('asignar un ticket notifica al asignado', () async {
    await repo.login(leader);
    await repo.assignTicket('t3', dev.id);

    final detail = await repo.fetchTicketDetail('t3');
    expect(detail.ticket.assigneeId, dev.id);
    expect(detail.ticket.events.last.type, 'ASSIGNED');

    await repo.logout();
    await repo.login(dev);
    final notifs = await repo.fetchNotifications();
    expect(notifs.first.kind, NotificationKind.assignment);
    expect(notifs.first.ticketId, 't3');
    expect(notifs.first.read, isFalse);
  });

  test('completar exige un enlace de PR válido', () async {
    await repo.login(dev);
    expect(
      () => repo.completeTicket('t1', 'https://example.com/pr/1'),
      throwsArgumentError,
    );
    await repo.completeTicket('t1', 'https://github.com/wellq/portal/pull/999');
    final d = await repo.fetchTicketDetail('t1');
    expect(d.ticket.status, TicketStatus.done);
    expect(d.ticket.runningSince, isNull);

    // los líderes reciben la notificación de completado
    await repo.logout();
    await repo.login(admin);
    final notifs = await repo.fetchNotifications();
    expect(
        notifs.any(
            (n) => n.kind == NotificationKind.completion && n.ticketId == 't1'),
        isTrue);
  });

  test('plantear pregunta bloquea el ticket y pausa el temporizador', () async {
    await repo.login(dev);
    await repo.raiseQuestion(
        't1', '¿Debo usar la librería estándar o la interna?');
    final d = await repo.fetchTicketDetail('t1');
    expect(d.ticket.status, TicketStatus.blocked);
    expect(d.ticket.runningSince, isNull);
    expect(d.permissions.canResolveQuestion, isTrue);

    await repo.resolveQuestion('t1', 'Usa la interna, ya está auditada.');
    final d2 = await repo.fetchTicketDetail('t1');
    expect(d2.ticket.status, TicketStatus.inProgress);
    expect(d2.ticket.runningSince, isNotNull);
  });

  test('redirigir cambia asignado y estado, y notifica', () async {
    await repo.login(dev); // Diego tiene t1 en progreso
    final sofia = (await repo.fetchUsers())
        .firstWhere((u) => u.fullName.startsWith('Sofía'));
    await repo.redirectTicket(
        't1', sofia.id, 'Sofía conoce mejor el módulo TOTP.');
    final d = await repo.fetchTicketDetail('t1');
    expect(d.ticket.status, TicketStatus.redirected);
    expect(d.ticket.assigneeId, sofia.id);
  });

  test('el dashboard del developer solo cuenta lo suyo', () async {
    await repo.login(dev);
    final dash = await repo.fetchDashboard();
    expect(dash.role, UserRole.developer);
    expect(dash.myTickets.every((t) => t.assigneeId == dev.id), isTrue);
    expect(dash.stats['mine'], dash.myTickets.length);
  });

  test('el dashboard del líder agrega los tres proyectos', () async {
    await repo.login(admin);
    final dash = await repo.fetchDashboard();
    expect(dash.projects.length, 3);
    expect(dash.stats['apps'], 3);
    // t2 está bloqueado en los datos semilla
    expect(dash.stats['blocked'], greaterThanOrEqualTo(1));
    expect(dash.attention.isNotEmpty, isTrue);
  });

  test('crear ticket notifica a líderes y al asignado', () async {
    await repo.login(leader);
    await repo.createTicket(
      epicId: 'e1',
      title: 'Auditoría de sesiones activas',
      priority: TicketPriority.high,
      assigneeId: dev.id,
    );
    final board = await repo.fetchBoard('a1');
    final epic1 = board.epics.firstWhere((e) => e.epic.id == 'e1');
    expect(epic1.tickets.any((t) => t.title == 'Auditoría de sesiones activas'),
        isTrue);

    await repo.logout();
    await repo.login(dev);
    final notifs = await repo.fetchNotifications();
    expect(notifs.first.kind, NotificationKind.assignment);
  });

  test('marcar todas como leídas deja el contador en cero', () async {
    await repo.login(admin);
    expect(await repo.unreadCount(), greaterThan(0));
    await repo.markAllNotificationsRead();
    expect(await repo.unreadCount(), 0);
  });

  test('incidencia permite tomar, comentar y enviar a revisión', () async {
    await repo.login(dev);
    await repo.takeIncident('i2');
    await repo.commentIncident('i2', 'Se corrigió la persistencia del idioma.');
    await repo.setIncidentStatus('i2', IncidentStatus.underReview);

    final incident = await repo.fetchIncident('i2');
    expect(incident.assigneeId, dev.id);
    expect(incident.status, IncidentStatus.underReview);
    expect(
        incident.comments.last.text, 'Se corrigió la persistencia del idioma.');
  });

  test('carga de equipo incluye todos los contadores', () async {
    await repo.login(leader);
    final members = await repo.fetchTeamWorkload();
    final diego = members.firstWhere((m) => m.user.id == dev.id);

    expect(diego.activeTickets, greaterThanOrEqualTo(diego.inProgress));
    expect(diego.blocked, greaterThanOrEqualTo(0));
    expect(diego.doneLast7d, greaterThanOrEqualTo(0));
    expect(diego.openIncidents, greaterThanOrEqualTo(0));
  });
}
