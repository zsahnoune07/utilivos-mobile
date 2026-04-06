import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/theme/app_design_tokens.dart';

void main() {
  test('builds light web theme payload from Flutter design tokens', () {
    final payload = AppDesignTokens.webThemePayload(Brightness.light);
    final tokens = payload['tokens']! as Map<String, String>;

    expect(payload['mode'], 'light');
    expect(tokens['--uv-color-background'], '#F8FAFC');
    expect(tokens['--uv-color-surface'], '#F8FAFC');
    expect(tokens['--uv-radius-md'], '12px');
    expect(tokens['--uv-space-4'], '16px');
    expect(tokens['--uv-font-size-headline-md'], '28px');
  });

  test('builds dark web theme payload from Flutter design tokens', () {
    final payload = AppDesignTokens.webThemePayload(Brightness.dark);
    final tokens = payload['tokens']! as Map<String, String>;

    expect(payload['mode'], 'dark');
    expect(tokens['--uv-color-background'], '#0E1416');
    expect(tokens['--uv-color-surface'], '#0E1416');
    expect(tokens['--uv-color-primary'], '#FB9551');
    expect(tokens['--uv-color-text'], '#E2F1EE');
    expect(tokens['--uv-font-family'], 'Roboto, "Segoe UI", sans-serif');
  });
}
