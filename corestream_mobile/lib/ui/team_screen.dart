import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../providers.dart';
import 'widgets.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    final team = ref.watch(teamWorkloadProvider);

    return AsyncView<List<MemberLoad>>(
      value: team,
      builder: (members) => RefreshIndicator(
        onRefresh: () => ref.refresh(teamWorkloadProvider.future),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final m = members[i];
            final roleColor = switch (m.user.role) {
              UserRole.admin => c.acc,
              UserRole.groupLeader => c.indigo,
              UserRole.developer => c.green,
            };
            return CsCard(
              child: Column(
                children: [
                  Row(children: [
                    UserAvatar(m.user, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.user.fullName,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w700)),
                          if (m.user.specialty != null)
                            Text(m.user.specialty!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: c.mut)),
                        ],
                      ),
                    ),
                    CsChip(
                      label: s('role_${m.user.role.wire}'),
                      color: roleColor,
                      dot: false,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (_, constraints) {
                      final width = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LoadMetric(width, m.activeTickets,
                              s('active_tickets'), c.acc),
                          _LoadMetric(
                              width, m.inProgress, s('st_prog'), c.indigo),
                          _LoadMetric(
                              width, m.blocked, s('st_blocked'), c.amber),
                          _LoadMetric(
                              width, m.doneLast7d, s('st_done_week'), c.green),
                          _LoadMetric(width, m.openIncidents,
                              s('open_incidents'), c.red),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadMetric extends StatelessWidget {
  const _LoadMetric(this.width, this.value, this.label, this.color);

  final double width;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Text('$value',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 2,
              style: TextStyle(fontSize: 10.5, color: c.mut, height: 1.2)),
        ),
      ]),
    );
  }
}
