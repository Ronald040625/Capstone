/// Bottom sheets de acciones sobre tickets: asignar, completar con PR,
/// plantear pregunta, reanudar, redirigir y crear ticket.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';
import 'widgets.dart';

// ------------------------------------------------------------ selector de user

class UserPicker extends ConsumerWidget {
  const UserPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.excludeUserId,
  });

  final String? selected;
  final ValueChanged<String> onSelect;
  final String? excludeUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final users = ref.watch(usersProvider).valueOrNull ?? const <User>[];
    final list = users
        .where((u) =>
            u.role != UserRole.admin && u.id != excludeUserId && u.isActive)
        .toList();
    return Column(
      children: [
        for (final u in list)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(u.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected == u.id ? c.accSoft : null,
                border: Border.all(
                    color: selected == u.id ? c.acc : Colors.transparent),
              ),
              child: Row(
                children: [
                  UserAvatar(u, size: 36),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.fullName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        if (u.specialty != null)
                          Text(u.specialty!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.mut)),
                      ],
                    ),
                  ),
                  if (selected == u.id)
                    Icon(Icons.check, color: c.acc, size: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------- asignar

Future<void> showAssignSheet(
    BuildContext context, WidgetRef ref, Ticket ticket) {
  final s = ref.read(stringsProvider);
  String? picked;
  return showCsSheet(
    context,
    StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            ticket.assigneeId == null ? s('assign') : s('reassign'),
            subtitle: '“${ticket.title}”\n${s('assign_sub')}',
          ),
          UserPicker(
              selected: picked, onSelect: (id) => setState(() => picked = id)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(s('cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: picked == null
                      ? null
                      : () async {
                          await ref
                              .read(repositoryProvider)
                              .assignTicket(ticket.id, picked!);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: Text(s('confirm')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ completar

Future<void> showCompleteSheet(
    BuildContext context, WidgetRef ref, Ticket ticket) {
  final s = ref.read(stringsProvider);
  final controller = TextEditingController();
  String? error;
  return showCsSheet(
    context,
    StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(s('complete'), subtitle: s('complete_sub')),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: s('pr_link'),
              hintText: 'https://github.com/wellq/portal/pull/431',
              errorText: error,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: cs(ctx).green),
            icon: const Icon(Icons.check),
            label: Text(s('complete')),
            onPressed: () async {
              final url = controller.text.trim();
              if (!prLinkPattern.hasMatch(url)) {
                setState(() => error = s('pr_invalid'));
                return;
              }
              try {
                await ref
                    .read(repositoryProvider)
                    .completeTicket(ticket.id, url);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                setState(() => error = s('pr_invalid'));
              }
            },
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------- pregunta / reanudar (texto)

Future<void> _showTextActionSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String subtitle,
  required String hint,
  required String cta,
  required Color ctaColor,
  required IconData icon,
  int minLength = 10,
  required Future<void> Function(String text) onSubmit,
}) {
  final s = ref.read(stringsProvider);
  final controller = TextEditingController();
  String? error;
  return showCsSheet(
    context,
    StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(title, subtitle: subtitle),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(hintText: hint, errorText: error),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ctaColor),
            icon: Icon(icon),
            label: Text(cta),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.length < minLength) {
                setState(() => error = s('q_short'));
                return;
              }
              await onSubmit(text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showQuestionSheet(
    BuildContext context, WidgetRef ref, Ticket ticket) {
  final s = ref.read(stringsProvider);
  return _showTextActionSheet(
    context,
    ref,
    title: s('raise_q'),
    subtitle: s('q_sub'),
    hint: s('q_ph'),
    cta: s('send'),
    ctaColor: cs(context).amber,
    icon: Icons.help_outline,
    onSubmit: (text) =>
        ref.read(repositoryProvider).raiseQuestion(ticket.id, text),
  );
}

Future<void> showResumeSheet(
    BuildContext context, WidgetRef ref, Ticket ticket) {
  final s = ref.read(stringsProvider);
  return _showTextActionSheet(
    context,
    ref,
    title: s('resume'),
    subtitle: s('rs_sub'),
    hint: '…',
    cta: s('resume'),
    ctaColor: cs(context).green,
    icon: Icons.play_arrow,
    minLength: 1,
    onSubmit: (text) =>
        ref.read(repositoryProvider).resolveQuestion(ticket.id, text),
  );
}

// ----------------------------------------------------------------- redirigir

Future<void> showRedirectSheet(
    BuildContext context, WidgetRef ref, Ticket ticket) {
  final s = ref.read(stringsProvider);
  final me = ref.read(authProvider);
  final controller = TextEditingController();
  String? picked;
  String? error;
  return showCsSheet(
    context,
    StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(s('redirect'), subtitle: s('rd_sub')),
          UserPicker(
            selected: picked,
            excludeUserId: me?.id,
            onSelect: (id) => setState(() => picked = id),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 2,
            maxLength: 500,
            decoration:
                InputDecoration(labelText: s('rd_reason'), errorText: error),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: cs(ctx).indigo),
            icon: const Icon(Icons.swap_horiz),
            label: Text(s('confirm')),
            onPressed: () async {
              final reason = controller.text.trim();
              if (picked == null) return;
              if (reason.length < 10) {
                setState(() => error = s('q_short'));
                return;
              }
              await ref
                  .read(repositoryProvider)
                  .redirectTicket(ticket.id, picked!, reason);
              if (ctx.mounted) {
                Navigator.pop(ctx); // cierra el sheet
                Navigator.of(context).maybePop(); // vuelve del detalle
              }
            },
          ),
        ],
      ),
    ),
  );
}

// --------------------------------------------------------------- nuevo ticket

Future<void> showNewTicketSheet(BuildContext context, WidgetRef ref,
    {required Epic epic}) {
  final s = ref.read(stringsProvider);
  final controller = TextEditingController();
  var priority = TicketPriority.medium;
  String? picked;
  String? error;
  return showCsSheet(
    context,
    StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(s('new_ticket'),
              subtitle: '${epic.name} — ${s('nt_sub')}'),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            decoration:
                InputDecoration(labelText: s('nt_title'), errorText: error),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TicketPriority>(
            initialValue: priority,
            decoration: InputDecoration(labelText: s('priority')),
            items: [
              for (final p in TicketPriority.values)
                DropdownMenuItem(value: p, child: Text(s('p_${p.wire}'))),
            ],
            onChanged: (v) =>
                setState(() => priority = v ?? TicketPriority.medium),
          ),
          const SizedBox(height: 12),
          Text('${s('assignee')} (${s('optional')})',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs(ctx).mut)),
          const SizedBox(height: 4),
          UserPicker(
              selected: picked,
              onSelect: (id) =>
                  setState(() => picked = picked == id ? null : id)),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(s('save')),
            onPressed: () async {
              final title = controller.text.trim();
              if (title.length < 5) {
                setState(() => error = s('nt_short'));
                return;
              }
              await ref.read(repositoryProvider).createTicket(
                    epicId: epic.id,
                    title: title,
                    priority: priority,
                    assigneeId: picked,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}
