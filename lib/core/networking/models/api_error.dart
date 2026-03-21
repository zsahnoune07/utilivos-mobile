class ApiError {
  const ApiError({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'unknown_error',
      message: json['message'] as String? ?? 'Unknown error',
      details: json['details'],
    );
  }
}
