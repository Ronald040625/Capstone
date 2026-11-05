import 'package:flutter_test/flutter_test.dart';

import 'package:corestream_mobile/core/i18n.dart';

void main() {
  test('todos los idiomas tienen el diccionario completo', () {
    expect(S.dictionaryVersion, greaterThan(1));
    for (final code in S.supported) {
      expect(S.missingKeys(code), isEmpty, reason: 'Faltan textos para $code');
    }
  });

  test('frances traduce textos y fechas visibles', () {
    final strings = S.byCode('fr');
    expect(strings('logout'), 'Se déconnecter');
    expect(shortDate('fr', DateTime(2026, 8, 29)), '29 août');
  });
}
