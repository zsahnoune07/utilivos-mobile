import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:utilivos_mobile/core/sessions/session_snapshot_normalizer.dart';
import 'package:utilivos_mobile/core/sessions/session_state_envelope.dart';

void main() {
  group('SessionStateEnvelope.tryParseRelaxed', () {
    test('parses strict envelope same as parse', () {
      final e = SessionStateEnvelope.build(
        toolSlug: 'my-tool',
        toolVersion: '1.0.0',
        payload: <String, dynamic>{'a': 1},
      );
      final relaxed = SessionStateEnvelope.tryParseRelaxed(e.serialize());
      expect(relaxed, isNotNull);
      expect(relaxed!.toolSlug, 'my-tool');
      expect(relaxed.payload['a'], 1);
    });

    test('coerces num schemaVersion and missing savedAt', () {
      final raw = jsonEncode(<String, dynamic>{
        'schemaVersion': 1.0,
        'toolSlug': 't',
        'payload': <String, dynamic>{'x': true},
      });
      final relaxed = SessionStateEnvelope.tryParseRelaxed(raw);
      expect(relaxed, isNotNull);
      expect(relaxed!.schemaVersion, 1);
      expect(relaxed.payload['x'], true);
    });

    test('treats bare object as payload when no envelope', () {
      final raw = jsonEncode(<String, dynamic>{'v': 1, 'name': 'x'});
      final relaxed = SessionStateEnvelope.tryParseRelaxed(raw);
      expect(relaxed, isNotNull);
      expect(relaxed!.schemaVersion, 0);
      expect(relaxed.payload['v'], 1);
      expect(relaxed.payload['name'], 'x');
    });

    test('invalid JSON returns null', () {
      expect(SessionStateEnvelope.tryParseRelaxed('not-json'), isNull);
    });
  });

  group('SessionSnapshotNormalizer', () {
    test('ephemeralStateJsonFromNamedSessionRow flattens envelope', () {
      final e = SessionStateEnvelope.build(
        toolSlug: 's',
        payload: <String, dynamic>{'k': 'v'},
      );
      final out = SessionSnapshotNormalizer.ephemeralStateJsonFromNamedSessionRow(
        e.serialize(),
      );
      expect(out, '{"k":"v"}');
    });

    test('ephemeralStateJsonFromNamedSessionRow passes through unknown', () {
      const raw = '{"legacy":true}';
      final out = SessionSnapshotNormalizer.ephemeralStateJsonFromNamedSessionRow(
        raw,
      );
      expect(out, raw);
    });

    test('payloadMapFromEphemeralStateJson reads envelope in ephemeral', () {
      final inner = SessionStateEnvelope.build(
        toolSlug: 's',
        payload: <String, dynamic>{'n': 2},
      );
      final map = SessionSnapshotNormalizer.payloadMapFromEphemeralStateJson(
        inner.serialize(),
      );
      expect(map['n'], 2);
    });

    test('payloadMapFromEphemeralStateJson handles raw tool JSON', () {
      final map = SessionSnapshotNormalizer.payloadMapFromEphemeralStateJson(
        '{"v":1}',
      );
      expect(map['v'], 1);
    });
  });
}
