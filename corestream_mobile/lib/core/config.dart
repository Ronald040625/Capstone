/// Configuración de la app.
///
/// Modo de datos:
///   - `demo` (por defecto): repositorio en memoria con los datos del
///     wireframe y simulación de notificaciones push. No requiere servidor.
///   - `api`: cliente HTTP contra el backend FastAPI (endpoints existentes +
///     paquete mobile_api). Se activa compilando con:
///
///       flutter run --dart-define=CS_API_URL=http://10.0.2.2:8000
///
///     (10.0.2.2 es localhost visto desde el emulador Android).
library;

class AppConfig {
  AppConfig._();

  /// URL base del backend. `same-origin` usa el mismo dominio del navegador.
  static const String _configuredApiUrl = String.fromEnvironment('CS_API_URL');

  static String get apiBaseUrl => _configuredApiUrl == 'same-origin'
      ? '${Uri.base.origin}/api'
      : _configuredApiUrl;

  static bool get isDemo => _configuredApiUrl.isEmpty;

  /// Intervalo de la simulación de eventos del equipo en modo demo.
  static const Duration demoEventInterval = Duration(seconds: 20);
}
