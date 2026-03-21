class CursorPage<T> {
  const CursorPage({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  factory CursorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromItemJson,
  ) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'Expected "items" list in cursor page payload.',
      );
    }

    final items = rawItems
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Each paginated item must be an object.',
            );
          }
          return fromItemJson(item);
        })
        .toList(growable: false);

    return CursorPage<T>(
      items: items,
      nextCursor: json['next_cursor'] as String?,
    );
  }
}
