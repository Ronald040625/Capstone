import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';
import 'dashboard_screen.dart';
import 'incidents_screens.dart';
import 'notifications_screen.dart';
import 'projects_screens.dart';
import 'settings_sheet.dart';
import 'team_screen.dart';
import 'ticket_detail_screen.dart';
import 'widgets.dart';

/// Contenedor principal: pestañas según rol, campana con badge y ajustes.
/// También escucha el stream de pushes y muestra el toast superior.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  void _openNotification(AppNotification n) {
    if (n.ticketId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: n.ticketId!)));
    } else if (n.incidentId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incidentId: n.incidentId!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)!;
    final s = ref.watch(stringsProvider);
    final c = cs(context);

    // Pushes entrantes -> toast superior estilo notificación del sistema.
    ref.listen(pushStreamProvider, (prev, next) {
      final n = next.valueOrNull;
      if (n != null && mounted) {
        showPushToast(context, ref, n, onOpen: _openNotification);
      }
    });

    final isLead = user.isLead;
    final pages = isLead
        ? const [
            DashboardScreen(),
            ProjectsScreen(),
            IncidentsScreen(),
            TeamScreen()
          ]
        : const [DashboardScreen(), ProjectsScreen(), IncidentsScreen()];
    if (_tab >= pages.length) _tab = 0;

    final titles = [
      '${s('hello')}, ${user.fullName.split(' ').first}',
      s('tab_projects'),
      s('tab_incidents'),
      if (isLead) s('tab_team'),
    ];
    final subtitles = [
      isLead ? s('home_sub_admin') : s('home_sub_dev'),
      null,
      null,
      if (isLead) s('workload'),
    ];

    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_tab]),
            if (subtitles[_tab] != null)
              Text(subtitles[_tab]!,
                  style: TextStyle(
                      fontSize: 12, color: c.mut, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s('notifications'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: s('settings'),
            onPressed: () => showSettingsSheet(context, ref),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: isLead ? s('tab_home') : s('tab_work'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: s('tab_projects'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.warning_amber_outlined),
            selectedIcon: const Icon(Icons.warning_amber),
            label: s('tab_incidents'),
          ),
          if (isLead)
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: s('tab_team'),
            ),
        ],
      ),
    );
  }
}

final pushStreamProvider = StreamProvider<AppNotification>(
  (ref) => ref.watch(repositoryProvider).incomingPush,
);
