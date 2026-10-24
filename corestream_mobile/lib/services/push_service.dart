/// Notificaciones push del dispositivo.
///
/// La app compila SIN Firebase: [NoopPushService] es la implementación
/// activa. En modo demo los "pushes" los simula DemoRepository (stream
/// incomingPush → toast + campana), y en modo API llegan por el WebSocket
/// autenticado mientras la app está abierta.
///
/// ACTIVAR PUSH REALES (FCM) — pasos:
///   1. `dart pub global activate flutterfire_cli`
///   2. `flutterfire configure` (crea firebase_options.dart y registra
///      android/ios en tu proyecto Firebase)
///   3. Descomentar firebase_core / firebase_messaging en pubspec.yaml
///   4. Descomentar la clase FirebasePushService de abajo y usarla en
///      providers.dart (pushServiceProvider)
///
/// El token obtenido se registra en el backend con POST /devices/
/// (repository.registerDevice), que es quien decide a quién notificar.
library;

abstract class PushService {
  /// Pide permiso al usuario y devuelve el token del dispositivo, o null si
  /// no hay proveedor de push disponible.
  Future<String?> init();

  /// Stream de tokens rotados (FCM onTokenRefresh). El repositorio debe
  /// re-registrar el dispositivo cuando emita.
  Stream<String> get tokenRefresh;
}

/// Implementación sin proveedor de push (por defecto).
class NoopPushService implements PushService {
  @override
  Future<String?> init() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Adaptador FCM real — descomentar tras `flutterfire configure` (ver arriba).
// ---------------------------------------------------------------------------
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import '../firebase_options.dart';
//
// class FirebasePushService implements PushService {
//   @override
//   Future<String?> init() async {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//     final messaging = FirebaseMessaging.instance;
//     final settings = await messaging.requestPermission();
//     if (settings.authorizationStatus == AuthorizationStatus.denied) {
//       return null;
//     }
//     return messaging.getToken();
//   }
//
//   @override
//   Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
// }
