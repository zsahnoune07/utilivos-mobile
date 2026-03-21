import 'package:flutter/material.dart';

class AppDesignTokens {
  const AppDesignTokens._();

  static const int designSystemVersion = 1;
  static const Color seedColor = Color(0xFFF8FAFC);
  static const String webFontFamily = 'Roboto, "Segoe UI", sans-serif';

  static const List<double> spacing = <double>[4, 8, 12, 16, 20, 24, 32];
  static const Map<String, double> radius = <String, double>{
    'sm': 8,
    'md': 12,
    'lg': 16,
    'xl': 24,
    'pill': 32,
  };
  static const Map<String, String> elevation = <String, String>{
    'none': 'none',
    'sm': '0 2px 8px rgba(15, 23, 42, 0.08)',
    'md': '0 8px 24px rgba(15, 23, 42, 0.12)',
  };

  static const Map<String, AppTypeScaleToken> headline =
      <String, AppTypeScaleToken>{
        'lg': AppTypeScaleToken(size: 32, weight: 600),
        'md': AppTypeScaleToken(size: 28, weight: 600),
        'sm': AppTypeScaleToken(size: 24, weight: 600),
      };
  static const Map<String, AppTypeScaleToken> body =
      <String, AppTypeScaleToken>{
        'lg': AppTypeScaleToken(size: 16, weight: 400),
        'md': AppTypeScaleToken(size: 14, weight: 400),
        'sm': AppTypeScaleToken(size: 12, weight: 400),
      };
  static const Map<String, AppTypeScaleToken> label =
      <String, AppTypeScaleToken>{
        'lg': AppTypeScaleToken(size: 14, weight: 500),
        'md': AppTypeScaleToken(size: 12, weight: 500),
        'sm': AppTypeScaleToken(size: 11, weight: 500),
      };

  static const AppColorPalette light = AppColorPalette(
    mode: 'light',
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFF8FAFC),
    primary: Color(0xFFFA8231),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFC75305),
    onSecondary: Color(0xFFFFFFFF),
    text: Color(0xFF190A01),
    muted: Color(0xFF394A48),
    error: Color(0xFF98000A),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF1A7F37),
    warning: Color(0xFFB05A00),
    surfaceAlt: Color(0xFFF1F5F9),
    outline: Color(0xFF576865),
  );

  static const AppColorPalette dark = AppColorPalette(
    mode: 'dark',
    background: Color(0xFF0E1416),
    surface: Color(0xFF0E1416),
    primary: Color(0xFFFB9551),
    onPrimary: Color(0xFFAE4804),
    secondary: Color(0xFFC75305),
    onSecondary: Color(0xFF321501),
    text: Color(0xFFE2F1EE),
    muted: Color(0xFFB8CAC7),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF520003),
    success: Color(0xFF7EE787),
    warning: Color(0xFFFFB86B),
    surfaceAlt: Color(0xFF132126),
    outline: Color(0xFF8C9F9B),
  );

  static AppColorPalette paletteFor(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  static TextTheme textTheme() {
    return TextTheme(
      headlineLarge: _textStyle(headline['lg']!),
      headlineMedium: _textStyle(headline['md']!, letterSpacing: -0.2),
      headlineSmall: _textStyle(headline['sm']!),
      bodyLarge: _textStyle(body['lg']!),
      bodyMedium: _textStyle(body['md']!),
      bodySmall: _textStyle(body['sm']!),
      labelLarge: _textStyle(label['lg']!),
      labelMedium: _textStyle(label['md']!),
      labelSmall: _textStyle(label['sm']!),
      titleMedium: _textStyle(const AppTypeScaleToken(size: 16, weight: 600)),
    );
  }

  static Map<String, dynamic> webThemePayload(Brightness brightness) {
    final palette = paletteFor(brightness);
    final tokens = <String, String>{
      '--uv-font-family': webFontFamily,
      ...palette.toWebColorVariables(),
    };

    for (final entry in radius.entries) {
      tokens['--uv-radius-${entry.key}'] = '${entry.value.toInt()}px';
    }

    for (var index = 0; index < spacing.length; index++) {
      tokens['--uv-space-${index + 1}'] = '${spacing[index].toInt()}px';
    }

    for (final entry in elevation.entries) {
      tokens['--uv-shadow-${entry.key}'] = entry.value;
    }

    _appendTypographyVariables(tokens, 'headline', headline);
    _appendTypographyVariables(tokens, 'body', body);
    _appendTypographyVariables(tokens, 'label', label);

    return <String, dynamic>{'mode': palette.mode, 'tokens': tokens};
  }

  static void _appendTypographyVariables(
    Map<String, String> tokens,
    String role,
    Map<String, AppTypeScaleToken> values,
  ) {
    for (final entry in values.entries) {
      tokens['--uv-font-size-$role-${entry.key}'] =
          '${entry.value.size.toInt()}px';
      tokens['--uv-font-weight-$role-${entry.key}'] = '${entry.value.weight}';
    }
  }

  static TextStyle _textStyle(
    AppTypeScaleToken token, {
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: token.size,
      fontWeight: _fontWeight(token.weight),
      letterSpacing: letterSpacing,
    );
  }

  static FontWeight _fontWeight(int value) {
    switch (value) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
      case 400:
      default:
        return FontWeight.w400;
    }
  }
}

class AppTypeScaleToken {
  const AppTypeScaleToken({required this.size, required this.weight});

  final double size;
  final int weight;
}

class AppColorPalette {
  const AppColorPalette({
    required this.mode,
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.text,
    required this.muted,
    required this.error,
    required this.onError,
    required this.success,
    required this.warning,
    required this.surfaceAlt,
    required this.outline,
  });

  final String mode;
  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color text;
  final Color muted;
  final Color error;
  final Color onError;
  final Color success;
  final Color warning;
  final Color surfaceAlt;
  final Color outline;

  Map<String, String> toWebColorVariables() {
    return <String, String>{
      '--uv-color-background': _hex(background),
      '--uv-color-surface': _hex(surface),
      '--uv-color-primary': _hex(primary),
      '--uv-color-on-primary': _hex(onPrimary),
      '--uv-color-secondary': _hex(secondary),
      '--uv-color-on-secondary': _hex(onSecondary),
      '--uv-color-text': _hex(text),
      '--uv-color-muted': _hex(muted),
      '--uv-color-error': _hex(error),
      '--uv-color-on-error': _hex(onError),
      '--uv-color-success': _hex(success),
      '--uv-color-warning': _hex(warning),
      '--uv-color-surface-alt': _hex(surfaceAlt),
      '--uv-color-outline': _hex(outline),
    };
  }

  String _hex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
