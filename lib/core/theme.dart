import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'meta.dart';

/// GitHub (Primer) colors — same palette as the web app's globals.css.
class AppColors extends ThemeExtension<AppColors> {
  final Color sidebar, muted, mutedFg, border, link, inset, success, danger, attention;
  final Map<Tone, ({Color fg, Color bg, Color border})> tones;

  const AppColors({
    required this.sidebar,
    required this.muted,
    required this.mutedFg,
    required this.border,
    required this.link,
    required this.inset,
    required this.success,
    required this.danger,
    required this.attention,
    required this.tones,
  });

  static const dark = AppColors(
    sidebar: Color(0xFF010409),
    muted: Color(0xFF151B23),
    mutedFg: Color(0xFF9198A1),
    border: Color(0xFF3D444D),
    link: Color(0xFF4493F8),
    inset: Color(0xFF010409),
    success: Color(0xFF3FB950),
    danger: Color(0xFFF85149),
    attention: Color(0xFFD29922),
    tones: {
      Tone.gray: (fg: Color(0xFF9198A1), bg: Color(0x26656C76), border: Color(0x66656C76)),
      Tone.blue: (fg: Color(0xFF4493F8), bg: Color(0x1A388BFD), border: Color(0x66388BFD)),
      Tone.green: (fg: Color(0xFF3FB950), bg: Color(0x262EA043), border: Color(0x662EA043)),
      Tone.yellow: (fg: Color(0xFFD29922), bg: Color(0x26BB8009), border: Color(0x66BB8009)),
      Tone.orange: (fg: Color(0xFFDB6D28), bg: Color(0x1ADB6D28), border: Color(0x66DB6D28)),
      Tone.red: (fg: Color(0xFFF85149), bg: Color(0x1AF85149), border: Color(0x66F85149)),
      Tone.purple: (fg: Color(0xFFAB7DF8), bg: Color(0x26AB7DF8), border: Color(0x66AB7DF8)),
      Tone.pink: (fg: Color(0xFFDB61A2), bg: Color(0x1ADB61A2), border: Color(0x66DB61A2)),
    },
  );

  static const light = AppColors(
    sidebar: Color(0xFFF6F8FA),
    muted: Color(0xFFF6F8FA),
    mutedFg: Color(0xFF59636E),
    border: Color(0xFFD1D9E0),
    link: Color(0xFF0969DA),
    inset: Color(0xFFF6F8FA),
    success: Color(0xFF1A7F37),
    danger: Color(0xFFD1242F),
    attention: Color(0xFF9A6700),
    tones: {
      Tone.gray: (fg: Color(0xFF59636E), bg: Color(0xFFF6F8FA), border: Color(0xFFD1D9E0)),
      Tone.blue: (fg: Color(0xFF0969DA), bg: Color(0xFFDDF4FF), border: Color(0x6654AEFF)),
      Tone.green: (fg: Color(0xFF1A7F37), bg: Color(0xFFDAFBE1), border: Color(0x664AC26B)),
      Tone.yellow: (fg: Color(0xFF9A6700), bg: Color(0xFFFFF8C5), border: Color(0x66D4A72C)),
      Tone.orange: (fg: Color(0xFFBC4C00), bg: Color(0xFFFFF1E5), border: Color(0x66FB8F44)),
      Tone.red: (fg: Color(0xFFD1242F), bg: Color(0xFFFFEBE9), border: Color(0x66FF8182)),
      Tone.purple: (fg: Color(0xFF8250DF), bg: Color(0xFFFBEFFF), border: Color(0x66C297FF)),
      Tone.pink: (fg: Color(0xFFBF3989), bg: Color(0xFFFFEFF7), border: Color(0x66FF80C8)),
    },
  );

  ({Color fg, Color bg, Color border}) tone(Tone t) => tones[t]!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Shortcut: `context.colors.mutedFg`
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        c: AppColors.dark,
        background: const Color(0xFF0D1117),
        foreground: const Color(0xFFF0F6FC),
        primary: const Color(0xFF238636),
        surfaceHigh: const Color(0xFF151B23),
        accent: const Color(0xFF262C36),
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        c: AppColors.light,
        background: const Color(0xFFFFFFFF),
        foreground: const Color(0xFF1F2328),
        primary: const Color(0xFF1F883D),
        surfaceHigh: const Color(0xFFF6F8FA),
        accent: const Color(0xFFEAEEF2),
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppColors c,
    required Color background,
    required Color foreground,
    required Color primary,
    required Color surfaceHigh,
    required Color accent,
  }) {
    final radius = BorderRadius.circular(6);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: c.link,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: c.mutedFg,
      surfaceContainerLowest: background,
      surfaceContainerLow: surfaceHigh,
      surfaceContainer: surfaceHigh,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: accent,
      outline: c.border,
      outlineVariant: c.border,
    );

    final inputBorder = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c.border));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: c.border,
      extensions: [c],
      visualDensity: VisualDensity.compact,
      // Text sizes close to GitHub's 14px base
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .englishLike
          .apply(bodyColor: foreground, displayColor: foreground)
          .copyWith(
            bodyMedium: TextStyle(fontSize: 14, color: foreground),
            bodySmall: TextStyle(fontSize: 12, color: c.mutedFg),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.sidebar,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: foreground),
        shape: Border(bottom: BorderSide(color: c.border)),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: c.sidebar, shape: const RoundedRectangleBorder()),
      cardTheme: CardThemeData(
        color: background,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.border)),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: brightness == Brightness.dark ? c.inset : background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.link, width: 2)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        hintStyle: TextStyle(color: c.mutedFg),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: surfaceHigh,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.link, shape: RoundedRectangleBorder(borderRadius: radius)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: background,
        selectedColor: accent,
        labelStyle: TextStyle(fontSize: 12, color: foreground),
      ),
      listTileTheme: ListTileThemeData(iconColor: c.mutedFg, dense: true),
      tabBarTheme: TabBarThemeData(
        labelColor: foreground,
        unselectedLabelColor: c.mutedFg,
        indicatorColor: const Color(0xFFFD8C73), // GitHub's orange underline
        dividerColor: c.border,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surfaceHigh, showDragHandle: true),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.border)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: foreground),
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.border)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.link, linearTrackColor: accent),
    );
  }
}
