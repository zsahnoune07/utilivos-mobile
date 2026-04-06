import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where recent search strings are stored (separate preference keys per surface).
enum RecentSearchScope {
  home,
  discover,
}

/// One row in Home search history: a text query or a tool opened from results.
sealed class HomeSearchHistoryEntry {
  const HomeSearchHistoryEntry();

  Map<String, dynamic> toJson();

  static HomeSearchHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final m = Map<String, dynamic>.from(raw);
    final kind = m['kind'] as String?;
    switch (kind) {
      case 'query':
        final t = m['text'] as String?;
        if (t == null || t.trim().isEmpty) {
          return null;
        }
        return HomeSearchHistoryQuery(t.trim());
      case 'tool':
        final slug = m['slug'] as String?;
        if (slug == null || slug.trim().isEmpty) {
          return null;
        }
        final name = (m['name'] as String?)?.trim();
        return HomeSearchHistoryTool(
          slug: slug.trim(),
          name: (name != null && name.isNotEmpty) ? name : slug.trim(),
        );
      default:
        return null;
    }
  }
}

final class HomeSearchHistoryQuery extends HomeSearchHistoryEntry {
  HomeSearchHistoryQuery(this.text);
  final String text;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'query',
    'text': text,
  };
}

final class HomeSearchHistoryTool extends HomeSearchHistoryEntry {
  HomeSearchHistoryTool({required this.slug, required this.name});
  final String slug;
  final String name;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'tool',
    'slug': slug,
    'name': name,
  };
}

/// One row in Discover search history: a text query or a tool opened from results.
sealed class DiscoverSearchHistoryEntry {
  const DiscoverSearchHistoryEntry();

  Map<String, dynamic> toJson();

  static DiscoverSearchHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final m = Map<String, dynamic>.from(raw);
    final kind = m['kind'] as String?;
    switch (kind) {
      case 'query':
        final t = m['text'] as String?;
        if (t == null || t.trim().isEmpty) {
          return null;
        }
        return DiscoverSearchHistoryQuery(t.trim());
      case 'tool':
        final slug = m['slug'] as String?;
        if (slug == null || slug.trim().isEmpty) {
          return null;
        }
        final name = (m['name'] as String?)?.trim();
        return DiscoverSearchHistoryTool(
          slug: slug.trim(),
          name: (name != null && name.isNotEmpty) ? name : slug.trim(),
        );
      default:
        return null;
    }
  }
}

final class DiscoverSearchHistoryQuery extends DiscoverSearchHistoryEntry {
  DiscoverSearchHistoryQuery(this.text);
  final String text;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'query',
    'text': text,
  };
}

final class DiscoverSearchHistoryTool extends DiscoverSearchHistoryEntry {
  DiscoverSearchHistoryTool({required this.slug, required this.name});
  final String slug;
  final String name;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': 'tool',
    'slug': slug,
    'name': name,
  };
}

/// Lightweight persisted recent search queries (SharedPreferences).
class RecentSearchStore {
  RecentSearchStore._(this._prefs);

  final SharedPreferences _prefs;

  static const int _maxEntries = 12;

  /// Legacy string-list key (queries only). Migrated on first read of [loadHomeSync].
  static const String _keyHomeLegacy = 'utilivos_recent_searches_home';
  static const String _keyHomeV2 = 'utilivos_home_search_history_v2';
  static const String _keyDiscoverLegacy = 'utilivos_recent_searches_discover';
  static const String _keyDiscoverV2 = 'utilivos_discover_search_history_v2';

  static Future<RecentSearchStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return RecentSearchStore._(prefs);
  }

  /// Home history: text queries and tools (see [HomeSearchHistoryEntry]).
  List<HomeSearchHistoryEntry> loadHomeSync() {
    final v2 = _prefs.getString(_keyHomeV2);
    if (v2 != null && v2.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(v2);
        if (decoded is List) {
          final out = <HomeSearchHistoryEntry>[];
          for (final Object? item in decoded) {
            final e = HomeSearchHistoryEntry.fromJson(item);
            if (e != null) {
              out.add(e);
            }
          }
          return out;
        }
      } catch (_) {
        // fall through to legacy
      }
    }
    final legacy = _prefs.getStringList(_keyHomeLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      return legacy
          .map((String q) => q.trim())
          .where((String q) => q.isNotEmpty)
          .map(HomeSearchHistoryQuery.new)
          .toList(growable: false);
    }
    return const <HomeSearchHistoryEntry>[];
  }

  Future<void> _persistHomeEntries(List<HomeSearchHistoryEntry> entries) async {
    final payload =
        jsonEncode(entries.map((HomeSearchHistoryEntry e) => e.toJson()).toList());
    await _prefs.setString(_keyHomeV2, payload);
  }

  Future<void> addHomeQuery(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final lower = trimmed.toLowerCase();
    final current = loadHomeSync();
    final deduped = current
        .where((HomeSearchHistoryEntry e) {
          if (e is HomeSearchHistoryQuery) {
            return e.text.trim().toLowerCase() != lower;
          }
          return true;
        })
        .toList(growable: false);
    final next = <HomeSearchHistoryEntry>[
      HomeSearchHistoryQuery(trimmed),
      ...deduped,
    ];
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    await _persistHomeEntries(next);
  }

  Future<void> addHomeTool({required String slug, required String name}) async {
    final s = slug.trim();
    if (s.isEmpty) {
      return;
    }
    final displayName = name.trim().isEmpty ? s : name.trim();
    final current = loadHomeSync();
    final deduped = current
        .where((HomeSearchHistoryEntry e) {
          if (e is HomeSearchHistoryTool) {
            return e.slug.toLowerCase() != s.toLowerCase();
          }
          return true;
        })
        .toList(growable: false);
    final next = <HomeSearchHistoryEntry>[
      HomeSearchHistoryTool(slug: s, name: displayName),
      ...deduped,
    ];
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    await _persistHomeEntries(next);
  }

  Future<void> clearHome() async {
    await _prefs.remove(_keyHomeV2);
    await _prefs.remove(_keyHomeLegacy);
  }

  List<DiscoverSearchHistoryEntry> loadDiscoverSync() {
    final v2 = _prefs.getString(_keyDiscoverV2);
    if (v2 != null && v2.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(v2);
        if (decoded is List) {
          final out = <DiscoverSearchHistoryEntry>[];
          for (final Object? item in decoded) {
            final e = DiscoverSearchHistoryEntry.fromJson(item);
            if (e != null) {
              out.add(e);
            }
          }
          return out;
        }
      } catch (_) {
        // fall through to legacy
      }
    }
    final legacy = _prefs.getStringList(_keyDiscoverLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      return legacy
          .map((String q) => q.trim())
          .where((String q) => q.isNotEmpty)
          .map(DiscoverSearchHistoryQuery.new)
          .toList(growable: false);
    }
    return const <DiscoverSearchHistoryEntry>[];
  }

  Future<void> _persistDiscoverEntries(
    List<DiscoverSearchHistoryEntry> entries,
  ) async {
    final payload = jsonEncode(
      entries.map((DiscoverSearchHistoryEntry e) => e.toJson()).toList(),
    );
    await _prefs.setString(_keyDiscoverV2, payload);
  }

  Future<void> addDiscoverQuery(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final lower = trimmed.toLowerCase();
    final current = loadDiscoverSync();
    final deduped = current.where((DiscoverSearchHistoryEntry e) {
      if (e is DiscoverSearchHistoryQuery) {
        return e.text.trim().toLowerCase() != lower;
      }
      return true;
    }).toList(growable: false);
    final next = <DiscoverSearchHistoryEntry>[
      DiscoverSearchHistoryQuery(trimmed),
      ...deduped,
    ];
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    await _persistDiscoverEntries(next);
  }

  Future<void> addDiscoverTool({required String slug, required String name}) async {
    final s = slug.trim();
    if (s.isEmpty) {
      return;
    }
    final displayName = name.trim().isEmpty ? s : name.trim();
    final current = loadDiscoverSync();
    final deduped = current.where((DiscoverSearchHistoryEntry e) {
      if (e is DiscoverSearchHistoryTool) {
        return e.slug.toLowerCase() != s.toLowerCase();
      }
      return true;
    }).toList(growable: false);
    final next = <DiscoverSearchHistoryEntry>[
      DiscoverSearchHistoryTool(slug: s, name: displayName),
      ...deduped,
    ];
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    await _persistDiscoverEntries(next);
  }

  Future<void> clearDiscover() async {
    await _prefs.remove(_keyDiscoverV2);
    await _prefs.remove(_keyDiscoverLegacy);
  }

  /// Text queries only (Discover scope). Home scope returns only query rows for backward compatibility.
  List<String> loadSync(RecentSearchScope scope) {
    return switch (scope) {
      RecentSearchScope.home => loadHomeSync()
          .whereType<HomeSearchHistoryQuery>()
          .map((HomeSearchHistoryQuery q) => q.text)
          .toList(growable: false),
      RecentSearchScope.discover => loadDiscoverSync()
          .whereType<DiscoverSearchHistoryQuery>()
          .map((DiscoverSearchHistoryQuery q) => q.text)
          .toList(growable: false),
    };
  }

  Future<List<String>> load(RecentSearchScope scope) async {
    return loadSync(scope);
  }

  Future<void> add(RecentSearchScope scope, String rawQuery) async {
    if (scope == RecentSearchScope.home) {
      await addHomeQuery(rawQuery);
      return;
    }
    await addDiscoverQuery(rawQuery);
  }

  Future<void> clear(RecentSearchScope scope) async {
    if (scope == RecentSearchScope.home) {
      await clearHome();
      return;
    }
    await clearDiscover();
  }
}
