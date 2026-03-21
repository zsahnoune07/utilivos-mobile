typedef ApiDataDecoder<T> = T Function(Object? rawData);

class ApiSuccessEnvelope<T> {
  const ApiSuccessEnvelope({required this.data});

  final T data;

  factory ApiSuccessEnvelope.fromJson(
    Map<String, dynamic> json,
    ApiDataDecoder<T> decodeData,
  ) {
    if (!json.containsKey('data')) {
      throw const FormatException('Expected "data" field in API response.');
    }

    return ApiSuccessEnvelope<T>(data: decodeData(json['data']));
  }
}
