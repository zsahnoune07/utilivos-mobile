class CursorPagination {
  const CursorPagination({this.cursor, this.limit = 20})
    : assert(limit > 0, 'limit must be greater than zero');

  final String? cursor;
  final int limit;

  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{
      'limit': limit,
      if (cursor != null && cursor!.trim().isNotEmpty) 'cursor': cursor,
    };
  }
}
