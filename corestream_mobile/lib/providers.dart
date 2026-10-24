/// Providers Riverpod de la app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';
import 'core/i18n.dart';
import 'data/api_repository.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'models/models.dart';
import 'services/push_service.dart';

// ------------------------------------------------------------- infraestructura

/// Se sobreescribe en main() con la instancia real.
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Sobreescrito en main()');
});

final repositoryProvider = Provider<CoreStreamRepository>((ref) {
  final repo =
      AppConfig.isDemo ? DemoRepository() : ApiRepository(AppConfig.apiBaseUrl);
  ref.onDispose(repo.dispose);
  return repo;
});

final pushServiceProvider = Provider<PushService>((ref) => NoopPushService());

/// Revisión de datos: cualquier provider que la observe se recalcula cuando
/// el repositorio emite un cambio (acción propia o evento simulado/WS).
final dataRevisionProvider = StreamProvider<int>(
  (ref) => ref.watch(repositoryProvider).changes,
);

// ------------------------------------------------------------------- sesión

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier(this._repo) : super(null);

  final CoreStreamRepository _repo;

  Future<void> loginAs(User user) async => state = await _repo.login(user);

  Future<void> logout() async {
    await _repo.logout();
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, User?>(
  (ref) => AuthNotifier(ref.watch(repositoryProvider)),
);

// -------------------------------------------------------------- preferencias

class ThemeDarkNotifier extends StateNotifier<bool> {
  ThemeDarkNotifier(this._prefs) : super(_prefs.getBool('dark') ?? true);
  final SharedPreferences _prefs;

  void set(bool dark) {
    state = dark;
    _prefs.setBool('dark', dark);
  }
}

/// true = tema oscuro (por defecto, como pidió el diseño).
final darkModeProvider = StateNotifierProvider<ThemeDarkNotifier, bool>(
    (ref) => ThemeDarkNotifier(ref.watch(prefsProvider)));

class LangNotifier extends StateNotifier<String> {
  LangNotifier(this._prefs) : super(_prefs.getString('lang') ?? 'es');
  final SharedPreferences _prefs;

  void set(String lang) {
    state = lang;
    _prefs.setString('lang', lang);
  }
}

final langProvider = StateNotifierProvider<LangNotifier, String>(
    (ref) => LangNotifier(ref.watch(prefsProvider)));

final stringsProvider = Provider<S>((ref) => S.byCode(ref.watch(langProvider)));

// -------------------------------------------------------------------- datos

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  ref.watch(dataRevisionProvider);
  ref.watch(authProvider);
  return ref.watch(repositoryProvider).fetchDashboard();
});

final projectsProvider =
    FutureProvider.autoDispose<List<ProjectSummary>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(repositoryProvider).fetchProjects();
});

final boardProvider =
    FutureProvider.autoDispose.family<Board, String>((ref, projectId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(repositoryProvider).fetchBoard(projectId);
});

final ticketDetailProvider =
    FutureProvider.autoDispose.family<TicketDetail, String>((ref, ticketId) {
  ref.watch(dataRevisionProvider);
  ref.watch(authProvider);
  return ref.watch(repositoryProvider).fetchTicketDetail(ticketId);
});

final incidentsProvider = FutureProvider.autoDispose<List<Incident>>((ref) {
  ref.watch(dataRevisionProvider);
  ref.watch(authProvider);
  return ref.watch(repositoryProvider).fetchIncidents();
});

final incidentProvider =
    FutureProvider.autoDispose.family<Incident, String>((ref, incidentId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(repositoryProvider).fetchIncident(incidentId);
});

final teamWorkloadProvider =
    FutureProvider.autoDispose<List<MemberLoad>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(repositoryProvider).fetchTeamWorkload();
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  ref.watch(dataRevisionProvider);
  ref.watch(authProvider);
  return ref.watch(repositoryProvider).fetchNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(dataRevisionProvider);
  ref.watch(authProvider);
  return ref.watch(repositoryProvider).unreadCount();
});

final usersProvider = FutureProvider.autoDispose<List<User>>((ref) {
  return ref.watch(repositoryProvider).fetchUsers();
});
