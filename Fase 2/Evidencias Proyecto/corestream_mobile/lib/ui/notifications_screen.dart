import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';
import 'incidents_screens.dart';
import 'ticket_detail_screen.dart';
import 'widgets.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(repositoryProvider).markNotificationRead(n.id);
    if (n.ticketId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: n.ticketId!)));
    } else if (n.incidentId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incidentId: n.incidentId!)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    final notifs = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s('notifications')),
        actions: [
          if ((notifs.valueOrNull ?? const []).any((n) => !n.read))
            TextButton(
              onPressed: () =>
                  ref.read(repositoryProvider).markAllNotificationsRead(),
              child:
                  Text(s('mark_all'), style: const TextStyle(fontSize: 12.5)),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: AsyncView<List<AppNotification>>(
        value: notifs,
        builder: (list) {
          if (list.isEmpty) {
            return EmptyState(s('no_notifs'), icon: Icons.notifications_none);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final n = list[i];
              return CsCard(
                onTap: () => _open(context, ref, n),
                padding: const EdgeInsets.all(13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NotificationIcon(kind: n.kind),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title(s, n.kind),
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(n.message,
                              style: TextStyle(
                                  fontSize: 12.5, color: c.mut, height: 1.45)),
                          const SizedBox(height: 4),
                          Text(relativeTime(s, n.ts),
                              style: TextStyle(fontSize: 11, color: c.faint)),
                        ],
                      ),
                    ),
                    if (!n.read)
                      Container(
                        margin: const EdgeInsets.only(top: 5, left: 6),
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: c.acc, shape: BoxShape.circle),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _title(S s, NotificationKind k) => switch (k) {
        NotificationKind.assignment => s('n_ASSIGNMENT'),
        NotificationKind.question => s('n_QUESTION'),
        NotificationKind.redirect => s('n_REDIRECT'),
        NotificationKind.completion => s('n_COMPLETION'),
        NotificationKind.incident => s('n_INCIDENT'),
        NotificationKind.system => s('n_SYSTEM'),
      };
}
