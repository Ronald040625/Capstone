import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/demo_repository.dart';
import '../models/models.dart';
import '../providers.dart';
import 'widgets.dart';

/// Estado visible del interruptor de simulación (se sincroniza con el repo).
final _simToggleProvider = StateProvider<bool>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo is DemoRepository ? repo.simulationEnabled : false;
});

Future<void> showSettingsSheet(BuildContext context, WidgetRef ref) {
  return showCsSheet(
    context,
    Consumer(builder: (ctx, ref, _) {
      final c = cs(ctx);
      final s = ref.watch(stringsProvider);
      final user = ref.watch(authProvider);
      final dark = ref.watch(darkModeProvider);
      final lang = ref.watch(langProvider);
      final repo = ref.watch(repositoryProvider);
      final demoRepo = repo is DemoRepository ? repo : null;

      final roleColor = user == null
          ? c.mut
          : switch (user.role) {
              UserRole.admin => c.acc,
              UserRole.groupLeader => c.indigo,
              UserRole.developer => c.green,
            };

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(s('settings')),
          if (user != null)
            Row(children: [
              UserAvatar(user, size: 44),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  CsChip(
                      label: s('role_${user.role.wire}'),
                      color: roleColor,
                      dot: false),
                ],
              ),
            ]),
          const SizedBox(height: 14),
          _SettingRow(
            label: s('theme'),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(s('dark'))),
                ButtonSegment(value: false, label: Text(s('light'))),
              ],
              selected: {dark},
              onSelectionChanged: (v) =>
                  ref.read(darkModeProvider.notifier).set(v.first),
            ),
          ),
          _SettingRow(
            label: s('language'),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'es', label: Text('Español')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {lang},
              onSelectionChanged: (v) =>
                  ref.read(langProvider.notifier).set(v.first),
            ),
          ),
          if (AppConfig.isDemo && demoRepo != null)
            _SettingRow(
              label: s('push_demo'),
              sublabel: s('push_demo_sub'),
              child: Switch(
                value: ref.watch(_simToggleProvider),
                onChanged: (v) {
                  demoRepo.simulationEnabled = v;
                  ref.read(_simToggleProvider.notifier).state = v;
                },
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: c.red),
            icon: const Icon(Icons.logout),
            label: Text(s('logout')),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      );
    }),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, this.sublabel, required this.child});

  final String label;
  final String? sublabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = cs(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                if (sublabel != null)
                  Text(sublabel!,
                      style: TextStyle(fontSize: 11.5, color: c.faint)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
