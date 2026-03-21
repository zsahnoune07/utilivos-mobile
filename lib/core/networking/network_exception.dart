enum NetworkExceptionKind {
  timeout,
  unauthorized,
  client,
  server,
  noConnection,
  cancelled,
  unexpected,
}

class NetworkException implements Exception {
  const NetworkException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  final NetworkExceptionKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Object? details;

  @override
  String toString() {
    final statusPart = statusCode != null ? ' status=$statusCode' : '';
    final codePart = code != null ? ' code=$code' : '';
    return 'NetworkException(kind=$kind$statusPart$codePart, message=$message)';
  }
}
