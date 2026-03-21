import 'api_error.dart';

class ApiErrorEnvelope {
  const ApiErrorEnvelope({required this.error});

  final ApiError error;

  factory ApiErrorEnvelope.fromJson(Map<String, dynamic> json) {
    final rawError = json['error'];
    if (rawError is! Map<String, dynamic>) {
      throw const FormatException('Expected "error" object in API response.');
    }

    return ApiErrorEnvelope(error: ApiError.fromJson(rawError));
  }
}
