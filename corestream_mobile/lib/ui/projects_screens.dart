import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/repository.dart';
import '../providers.dart';
import 'ticket_detail_screen.dart';
import 'ticket_sheets.dart';
import 'widgets.dart';

// ------------------------------------------------------------ lista proyectos

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return AsyncView<List<ProjectSummary>>(
      value: projects,
      builder: (list) => RefreshIndicator(
        onRefresh: () => ref.refresh(projectsProvider.future),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => ProjectCard(summary: list[i]),
        ),
      ),
    );
  }
}

class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.summary});
  final ProjectSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    final p = summary;
    return CsCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BoardScreen(projectId: p.project.id))),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: p.project.color,
                borderRadius: BorderRadius.circular(13)),
            child: Text(p.project.code,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.project.name,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: c.mut),
                    children: [
                      TextSpan(
                          text:
                              '${p.epicsCount} ${s('epics')} · ${p.pending} ${s('pending')}'),
                      if (p.overdue > 0)
                        TextSpan(
                            text: ' · ${p.overdue} ${s('overdue')}',
                            style: TextStyle(
                                color: c.red, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ProgressBar(p.progress),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${(p.progress * 100).round()}%',
              style: TextStyle(
                  fontSize: 12, color: c.mut, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- tablero

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    final board = ref.watch(boardProvider(projectId));
    final me = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(board.valueOrNull?.project.name ?? ''),
      ),
      body: AsyncView<Board>(
        value: board,
        builder: (b) => RefreshIndicator(
          onRefresh: () => ref.refresh(boardProvider(projectId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final e in b.epics) ...[
                CsCard(
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.epic.name,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              '${e.done} ${s('of')} ${e.tickets.length} ${s('tickets')} · ${(e.progress * 100).round()}%',
                              style: TextStyle(fontSize: 12, color: c.mut),
                            ),
                            const SizedBox(height: 8),
                            ProgressBar(e.progress),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: c.line.withValues(alpha: 0.6)),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final t in e.tickets) ...[
                              TicketRow(
                                t,
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => TicketDetailScreen(
                                            ticketId: t.id))),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (me != null && me.isLead)
                              OutlinedButton.icon(
                                onPressed: () => showNewTicketSheet(
                                    context, ref,
                                    epic: e.epic),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(s('new_ticket')),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
