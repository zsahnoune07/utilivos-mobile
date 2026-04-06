import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:utilivos_mobile/shared/cache/tool_icon_cache_manager.dart';
import 'package:utilivos_mobile/shared/widgets/tool_thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PathProviderPlatform.instance = _TestPathProviderPlatform();
  });

  testWidgets('falls back to icon when URL is invalid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: ToolThumbnail(imageUrl: 'file:///tmp/icon.png')),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.extension_outlined), findsOneWidget);
  });

  testWidgets('resolves relative URL with base URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: ToolThumbnail(
            imageUrl: '/v1/plugins/json-tools/icon',
            baseUrl: 'https://api.example.test',
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(
      image.imageUrl,
      'https://api.example.test/v1/plugins/json-tools/icon',
    );
    expect(image.cacheManager, same(ToolIconCacheManager.instance));
  });

  testWidgets('uses shared cache manager across multiple thumbnails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Column(
            children: <Widget>[
              ToolThumbnail(
                imageUrl: '/v1/plugins/a/icon',
                baseUrl: 'https://api.example.test',
              ),
              ToolThumbnail(
                imageUrl: '/v1/plugins/a/icon',
                baseUrl: 'https://api.example.test',
              ),
            ],
          ),
        ),
      ),
    );

    final widgets = tester.widgetList<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(widgets, hasLength(2));
    for (final widget in widgets) {
      expect(widget.cacheManager, same(ToolIconCacheManager.instance));
    }
  });
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  Future<String> _makeTempPath(String prefix) async {
    final directory = await Directory.systemTemp.createTemp(prefix);
    return directory.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return _makeTempPath('utilivos-cache-test');
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _makeTempPath('utilivos-support-test');
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return _makeTempPath('utilivos-app-cache-test');
  }
}
