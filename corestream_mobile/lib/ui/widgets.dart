/// Widgets compartidos: chips de estado, avatares, tarjetas, barras de
/// progreso, toasts push y utilidades de bottom sheet.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';

// ------------------------------------------------------------------ colores

Color statusColor(BuildContext context, TicketStatus s) {
  final c = cs(context);
  return switch (s) {
    TicketStatus.todo => c.gray,
    TicketStatus.inProgress => c.acc,
    TicketStatus.blocked => c.amber,
    TicketStatus.redirected => c.indigo,
    TicketStatus.done => c.green,
  };
}

Color statusSoft(BuildContext context, TicketStatus s) {
  final c = cs(context);
  return switch (s) {
    TicketStatus.todo => c.graySoft,
    TicketStatus.inProgress => c.accSoft,
    TicketStatus.blocked => c.amberSoft,
    TicketStatus.redirected => c.indigoSoft,
    TicketStatus.done => c.greenSoft,
  };
}

Color incidentStatusColor(BuildContext context, IncidentStatus s) {
  final c = cs(context);
  return switch (s) {
    IncidentStatus.open || IncidentStatus.reopened => c.red,
    IncidentStatus.inProgress => c.acc,
    IncidentStatus.underReview => c.amber,
    IncidentStatus.resolved => c.green,
    IncidentStatus.closed => c.gray,
  };
}

Color severityColor(BuildContext context, IncidentSeverity s) {
  final c = cs(context);
  return switch (s) {
    IncidentSeverity.critical => c.red,
    IncidentSeverity.high => const Color(0xFFF07E3E),
    IncidentSeverity.medium => c.amber,
    IncidentSeverity.low => c.green,
  };
}

Color priorityColor(BuildContext context, TicketPriority p) {
  final c = cs(context);
  return switch (p) {
    TicketPriority.low => c.green,
    TicketPriority.medium => c.amber,
    TicketPriority.high => const Color(0xFFF07E3E),
    TicketPriority.urgent => c.red,
  };
}

// ------------------------------------------------------------------- chips

class CsChip extends StatelessWidget {
  const CsChip(
      {super.key,
      required this.label,
      required this.color,
      this.soft,
      this.dot = true});

  final String label;
  final Color color;
  final Color? soft;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: soft ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class StatusChip extends ConsumerWidget {
  const StatusChip(this.status, {super.key});
  final TicketStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return CsChip(
      label: s('s_${status.wire}'),
      color: statusColor(context, status),
      soft: statusSoft(context, status),
    );
  }
}

class IncidentStatusChip extends ConsumerWidget {
  const IncidentStatusChip(this.status, {super.key});
  final IncidentStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return CsChip(
        label: s('is_${status.wire}'),
        color: incidentStatusColor(context, status));
  }
}

class SeverityChip extends ConsumerWidget {
  const SeverityChip(this.severity, {super.key});
  final IncidentSeverity severity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return CsChip(
        label: s('sev_${severity.wire}'),
        color: severityColor(context, severity),
        dot: false);
  }
}

class PriorityDot extends StatelessWidget {
  const PriorityDot(this.priority, {super.key, this.size = 8});
  final TicketPriority priority;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: priorityColor(context, priority), shape: BoxShape.circle),
      );
}

// ----------------------------------------------------------------- avatares

class UserAvatar extends StatelessWidget {
  const UserAvatar(this.user, {super.key, this.size = 34});
  final User? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: user?.avatarColor ?? c.line,
        shape: BoxShape.circle,
      ),
      child: Text(
        user?.initials ?? '–',
        style: TextStyle(
          color: user == null ? c.mut : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ tarjetas

class CsCard extends StatelessWidget {
  const CsCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.line.withValues(alpha: 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 6,
        backgroundColor: c.line.withValues(alpha: 0.5),
        valueColor: AlwaysStoppedAnimation(c.green),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8, left: 2),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: cs(context).faint),
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile(
      {super.key, required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return CsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color ?? c.ink,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.mut)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 34, color: c.faint),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.faint, fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }
}

/// Envuelve un AsyncValue con carga/errores coherentes.
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return value.when(
      data: builder,
      loading: () => const Center(
          child: Padding(
              padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) =>
          EmptyState(s('error_generic'), icon: Icons.cloud_off_outlined),
    );
  }
}

// -------------------------------------------------------------- fila ticket

class TicketRow extends ConsumerWidget {
  const TicketRow(this.ticket,
      {super.key, this.projectName, required this.onTap});

  final Ticket ticket;
  final String? projectName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final repo = ref.watch(repositoryProvider);
    final assignee = repo.userById(ticket.assigneeId);

    return CsCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          PriorityDot(ticket.priority),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (ticket.number > 0)
                      Text('T-${ticket.number}',
                          style: TextStyle(
                              fontSize: 11,
                              color: c.faint,
                              fontFamily: 'monospace')),
                    if (projectName != null)
                      Text(projectName!,
                          style: TextStyle(fontSize: 11.5, color: c.mut)),
                    StatusChip(ticket.status),
                    if (ticket.dueDate != null)
                      Text(
                        '${ticket.isOverdue ? '⚠ ' : ''}${shortDate(lang, ticket.dueDate!)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ticket.isOverdue ? c.red : c.mut,
                          fontWeight: ticket.isOverdue
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    if (ticket.subtasks.isNotEmpty)
                      Text('☑ ${ticket.subtasksDone}/${ticket.subtasks.length}',
                          style: TextStyle(fontSize: 11.5, color: c.mut)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: assignee?.fullName ?? s('unassigned'),
            child: UserAvatar(assignee, size: 26),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- toast push

/// Muestra una notificación entrante como banner flotante superior (push).
void showPushToast(BuildContext context, WidgetRef ref, AppNotification n,
    {required void Function(AppNotification) onOpen}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final c = cs(context);
  final s = ref.read(stringsProvider);

  late OverlayEntry entry;
  final timer = Timer(const Duration(seconds: 5), () {
    if (entry.mounted) entry.remove();
  });

  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            timer.cancel();
            if (entry.mounted) entry.remove();
            onOpen(n);
          },
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NotificationIcon(kind: n.kind, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CORESTREAM · ${s('now').toUpperCase()}',
                          style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w700,
                              color: c.faint)),
                      const SizedBox(height: 2),
                      Text(s('n_${_kindWire(n.kind)}'),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.ink)),
                      Text(n.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: c.mut, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

String _kindWire(NotificationKind k) => switch (k) {
      NotificationKind.assignment => 'ASSIGNMENT',
      NotificationKind.question => 'QUESTION',
      NotificationKind.redirect => 'REDIRECT',
      NotificationKind.completion => 'COMPLETION',
      NotificationKind.incident => 'INCIDENT',
      NotificationKind.system => 'SYSTEM',
    };

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key, required this.kind, this.size = 36});

  final NotificationKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    final (icon, color) = switch (kind) {
      NotificationKind.assignment => (Icons.assignment_ind_outlined, c.acc),
      NotificationKind.question => (Icons.help_outline, c.amber),
      NotificationKind.redirect => (Icons.swap_horiz, c.indigo),
      NotificationKind.completion => (Icons.check_circle_outline, c.green),
      NotificationKind.incident => (Icons.warning_amber_outlined, c.red),
      NotificationKind.system => (Icons.add_circle_outline, c.acc),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

// -------------------------------------------------------------- bottom sheet

Future<T?> showCsSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 8,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: cs(ctx).line, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          child,
        ],
      ),
    ),
  );
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: TextStyle(fontSize: 13, color: c.mut, height: 1.45)),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}
