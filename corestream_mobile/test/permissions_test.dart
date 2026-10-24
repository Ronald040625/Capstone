// Tests del cálculo de permisos: espejo de los tests del backend
// (mobile_api/tests/test_permissions.py). Corren sin UI ni red.

import 'package:flutter_test/flutter_test.dart';

import 'package:corestream_mobile/models/models.dart';

void main() {
  const dev = 'u-dev';
  const other = 'u-other';

  TicketPermissions perms(
          UserRole role, String uid, TicketStatus st, String? assignee) =>
      TicketPermissions.compute(
          role: role, userId: uid, status: st, assigneeId: assignee);

  test('developer asignado en progreso: trabaja pero no administra', () {
    final p = perms(UserRole.developer, dev, TicketStatus.inProgress, dev);
    expect(p.canComplete, isTrue);
    expect(p.canQuestion, isTrue);
    expect(p.canRedirect, isTrue);
    expect(p.canEditSubtasks, isTrue);
    expect(p.canAssign, isFalse);
    expect(p.canStart, isFalse);
    expect(p.canDelete, isFalse);
  });

  test('developer no asignado: solo lectura', () {
    final p = perms(UserRole.developer, other, TicketStatus.inProgress, dev);
    expect(p.anyWorkAction, isFalse);
    expect(p.canAssign, isFalse);
    expect(p.canEditSubtasks, isFalse);
  });

  test('comenzar solo desde TODO o REDIRECTED', () {
    for (final st in [TicketStatus.todo, TicketStatus.redirected]) {
      expect(perms(UserRole.developer, dev, st, dev).canStart, isTrue,
          reason: '$st');
    }
    expect(
        perms(UserRole.developer, dev, TicketStatus.inProgress, dev).canStart,
        isFalse);
  });

  test('bloqueado: resuelven el asignado o un líder, nadie más', () {
    expect(
        perms(UserRole.developer, dev, TicketStatus.blocked, dev)
            .canResolveQuestion,
        isTrue);
    expect(
        perms(UserRole.groupLeader, other, TicketStatus.blocked, dev)
            .canResolveQuestion,
        isTrue);
    expect(
        perms(UserRole.developer, other, TicketStatus.blocked, dev)
            .canResolveQuestion,
        isFalse);
  });

  test('líder asigna y edita, pero no trabaja tickets ajenos', () {
    final p = perms(UserRole.groupLeader, other, TicketStatus.todo, dev);
    expect(p.canAssign, isTrue);
    expect(p.canEdit, isTrue);
    expect(p.canEditSubtasks, isTrue);
    expect(p.canStart, isFalse);
    expect(p.canComplete, isFalse);
    expect(p.canDelete, isFalse);
  });

  test('solo ADMIN elimina', () {
    expect(
        perms(UserRole.admin, other, TicketStatus.todo, dev).canDelete, isTrue);
    expect(perms(UserRole.groupLeader, other, TicketStatus.todo, dev).canDelete,
        isFalse);
  });

  test('un ticket DONE es intocable', () {
    for (final role in UserRole.values) {
      final p = perms(role, dev, TicketStatus.done, dev);
      expect(p.canAssign, isFalse, reason: '$role');
      expect(p.canEditSubtasks, isFalse, reason: '$role');
      expect(p.anyWorkAction, isFalse, reason: '$role');
    }
  });

  test('validación de enlaces de PR (misma regla que el backend)', () {
    expect(prLinkPattern.hasMatch('https://github.com/wellq/portal/pull/431'),
        isTrue);
    expect(
        prLinkPattern
            .hasMatch('https://gitlab.com/wellq/api/-/merge_requests/9'),
        isTrue);
    expect(
        prLinkPattern
            .hasMatch('https://bitbucket.org/wellq/repo/pull-requests/2'),
        isTrue);
    expect(prLinkPattern.hasMatch('http://github.com/inseguro'), isFalse);
    expect(prLinkPattern.hasMatch('https://example.com/pr/1'), isFalse);
    expect(prLinkPattern.hasMatch('foo'), isFalse);
  });
}
