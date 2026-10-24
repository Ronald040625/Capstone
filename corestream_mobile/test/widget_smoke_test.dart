// Smoke test de UI: login por rol y navegación básica.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:corestream_mobile/main.dart';
import 'package:corestream_mobile/providers.dart';
import 'package:corestream_mobile/data/demo_repository.dart';

void main() {
  test('el idioma se carga y persiste', () async {
    SharedPreferences.setMockInitialValues({'lang': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    expect(container.read(langProvider), 'en');
    container.read(langProvider.notifier).set('es');
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString('lang'), 'es');
  });

  testWidgets('login como Admin muestra el dashboard y permite cerrar sesión',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    // desactivar la simulación para no dejar timers pendientes
    final repo = container.read(repositoryProvider);
    (repo as DemoRepository).simulationEnabled = false;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const CoreStreamApp(),
    ));
    await tester.pumpAndSettle();

    // pantalla de login con los tres roles demo
    expect(find.text('CoreStream'), findsOneWidget);
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('Diego Ramos'), findsOneWidget);

    // entrar como Admin
    await tester.tap(find.text('Ana Torres'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hola, Ana'), findsOneWidget);
    expect(find.text('Proyectos'), findsWidgets);
    expect(find.text('Portal Clientes'), findsWidgets);

    // cerrar sesión (cancela el timer de simulación)
    await container.read(authProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(find.text('Ana Torres'), findsOneWidget);
  });
}
