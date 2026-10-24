import 'package:flutter/material.dart';

/// Paleta semántica de CoreStream (idéntica al wireframe y a la web):
/// azul = en progreso / acción, ámbar = bloqueado, verde = hecho,
/// rojo = urgente/crítico, índigo = redirigido.
@immutable
class CsColors extends ThemeExtension<CsColors> {
  const CsColors({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.mut,
    required this.faint,
    required this.acc,
    required this.accSoft,
    required this.amber,
    required this.amberSoft,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.indigo,
    required this.indigoSoft,
    required this.gray,
    required this.graySoft,
  });

  final Color bg;
  final Color surface;
  final Color raised;
  final Color line;
  final Color ink;
  final Color mut;
  final Color faint;
  final Color acc;
  final Color accSoft;
  final Color amber;
  final Color amberSoft;
  final Color green;
  final Color greenSoft;
  final Color red;
  final Color redSoft;
  final Color indigo;
  final Color indigoSoft;
  final Color gray;
  final Color graySoft;

  static const dark = CsColors(
    bg: Color(0xFF0E1420),
    surface: Color(0xFF161E2D),
    raised: Color(0xFF1D2739),
    line: Color(0xFF26314A),
    ink: Color(0xFFE9EEF7),
    mut: Color(0xFF8D98AE),
    faint: Color(0xFF5C6880),
    acc: Color(0xFF4C8DFF),
    accSoft: Color(0x244C8DFF),
    amber: Color(0xFFF2A93B),
    amberSoft: Color(0x24F2A93B),
    green: Color(0xFF2FBF71),
    greenSoft: Color(0x242FBF71),
    red: Color(0xFFF0554E),
    redSoft: Color(0x24F0554E),
    indigo: Color(0xFF8B7CF6),
    indigoSoft: Color(0x268B7CF6),
    gray: Color(0xFF8D98AE),
    graySoft: Color(0x248D98AE),
  );

  static const light = CsColors(
    bg: Color(0xFFF2F5FA),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    line: Color(0xFFDFE5F0),
    ink: Color(0xFF17202F),
    mut: Color(0xFF5D6980),
    faint: Color(0xFF93A0B5),
    acc: Color(0xFF2F6FE4),
    accSoft: Color(0x1A2F6FE4),
    amber: Color(0xFFC97F10),
    amberSoft: Color(0x24E29920),
    green: Color(0xFF1E9E5C),
    greenSoft: Color(0x1F1E9E5C),
    red: Color(0xFFD93B34),
    redSoft: Color(0x1AD93B34),
    indigo: Color(0xFF6A5AE0),
    indigoSoft: Color(0x1F6A5AE0),
    gray: Color(0xFF71809A),
    graySoft: Color(0x1F71809A),
  );

  @override
  CsColors copyWith() => this;

  @override
  CsColors lerp(ThemeExtension<CsColors>? other, double t) =>
      t < 0.5 ? this : (other as CsColors? ?? this);
}

/// Acceso corto a la paleta desde cualquier widget.
CsColors cs(BuildContext context) => Theme.of(context).extension<CsColors>()!;

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? CsColors.dark : CsColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.acc,
    brightness: brightness,
    surface: c.surface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: c.ink,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accSoft,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.mut),
      ),
    ),
    dividerTheme:
        DividerThemeData(color: c.line.withValues(alpha: 0.6), space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.acc, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: c.line),
        foregroundColor: c.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
