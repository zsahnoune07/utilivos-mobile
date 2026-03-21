import 'dart:math';

class RequestIdGenerator {
  RequestIdGenerator._();

  static final Random _random = Random();

  static String next() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randomPart = _random
        .nextInt(0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'mob-$now-$randomPart';
  }
}
