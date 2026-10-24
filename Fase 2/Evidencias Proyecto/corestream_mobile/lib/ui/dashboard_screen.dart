import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../providers.dart';
import 'incidents_screens.dart';
import 'projects_screens.dart';
import 'ticket_detail_screen.dart';
import 'widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return AsyncView<Dashboard>(
      value: dashboard,
      builder: (d) => RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child:
            d.role == UserRole.developer ? _DeveloperHome(d) : _LeaderHome(d),
      ),
    );
  }
}

class _LeaderHome extends ConsumerWidget {
  const _LeaderHome(this.d);
  final Dashboard d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            StatTile(value: '${d.stats['apps']}', label: s('st_apps')),
            StatTile(value: '${d.stats['open']}', label: s('st_open')),
            StatTile(
                value: '${d.stats['blocked']}',
                label: s('st_blocked'),
                color: c.amber),
            StatTile(
                value: '${d.stats['late']}', label: s('st_late'), color: c.red),
          ],
        ),
        SectionLabel(s('proj_status')),
        for (final p in d.projects) ...[
          ProjectCard(summary: p),
          const SizedBox(height: 10),
        ],
        SectionLabel(s('attention')),
        if (d.attention.isEmpty)
          EmptyState(s('all_clear'), icon: Icons.verified_outlined)
        else
          for (final a in d.attention) ...[
            _AttentionRow(a),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _AttentionRow extends ConsumerWidget {
  const _AttentionRow(this.item);
  final AttentionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.ticket != null) {
      return TicketRow(
        item.ticket!,
        projectName: item.projectName,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TicketDetailScreen(ticketId: item.ticket!.id))),
      );
    }
    return IncidentRow(
      item.incident!,
      projectName: item.projectName,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incidentId: item.incident!.id))),
    );
  }
}

class _DeveloperHome extends ConsumerWidget {
  const _DeveloperHome(this.d);
  final Dashboard d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            StatTile(value: '${d.stats['mine']}', label: s('st_mine')),
            StatTile(
                value: '${d.stats['prog']}', label: s('st_prog'), color: c.acc),
            StatTile(
                value: '${d.stats['doneWeek']}',
                label: s('st_done_week'),
                color: c.green),
            StatTile(
                value: '${d.stats['incidents']}',
                label: s('my_incidents'),
                color: c.amber),
          ],
        ),
        SectionLabel(s('st_mine')),
        if (d.myTickets.isEmpty)
          EmptyState(s('no_tickets'), icon: Icons.celebration_outlined)
        else
          for (final t in d.myTickets) ...[
            TicketRow(
              t,
              projectName:
                  ref.watch(repositoryProvider).projectOfTicket(t)?.name,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TicketDetailScreen(ticketId: t.id))),
            ),
            const SizedBox(height: 10),
          ],
        if (d.myIncidents.isNotEmpty) ...[
          SectionLabel(s('my_incidents')),
          for (final i in d.myIncidents) ...[
            IncidentRow(
              i,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => IncidentDetailScreen(incidentId: i.id))),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}
