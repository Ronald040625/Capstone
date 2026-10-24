import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';
import 'widgets.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    final options = ref.watch(loginOptionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4C8DFF), Color(0xFF2FBF71)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFF4C8DFF).withValues(alpha: 0.45),
                          blurRadius: 26,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  child: const Text('C',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 16),
              Text(s('app_name'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(s('login_sub'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.mut, fontSize: 13.5, height: 1.5)),
              const SizedBox(height: 26),
              AsyncView<List<User>>(
                value: options,
                builder: (users) => Column(
                  children: [
                    for (final u in users) ...[
                      _RoleCard(
                          user: u,
                          onTap: () =>
                              ref.read(authProvider.notifier).loginAs(u)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 3),
              Text(
                AppConfig.isDemo ? s('demo_note') : s('api_mode'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: c.faint),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

final loginOptionsProvider = FutureProvider<List<User>>(
  (ref) => ref.watch(repositoryProvider).loginOptions(),
);

class _RoleCard extends ConsumerWidget {
  const _RoleCard({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cs(context);
    final s = ref.watch(stringsProvider);
    final roleColor = switch (user.role) {
      UserRole.admin => c.acc,
      UserRole.groupLeader => c.indigo,
      UserRole.developer => c.green,
    };
    return CsCard(
      onTap: onTap,
      child: Row(
        children: [
          UserAvatar(user, size: 46),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
                if (user.specialty != null)
                  Text(user.specialty!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.mut)),
                const SizedBox(height: 5),
                CsChip(
                    label: s('role_${user.role.wire}'),
                    color: roleColor,
                    dot: false),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.faint),
        ],
      ),
    );
  }
}
