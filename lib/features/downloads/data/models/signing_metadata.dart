class SigningMetadata {
  const SigningMetadata({
    required this.signingPublicKey,
    required this.signingPublicKeyId,
    required this.signingPublicKeyAlgorithm,
    required this.publicKeySignature,
    required this.publicKeySignatureAlgorithm,
    required this.publicKeySignaturePayload,
  });

  final String signingPublicKey;
  final String signingPublicKeyId;
  final String signingPublicKeyAlgorithm;
  final String publicKeySignature;
  final String publicKeySignatureAlgorithm;
  final PublicKeySignaturePayload publicKeySignaturePayload;

  factory SigningMetadata.fromJson(Map<String, dynamic> json) {
    final signingPublicKey = json['signing_public_key'];
    final signingPublicKeyId = json['signing_public_key_id'];
    final signingPublicKeyAlgorithm = json['signing_public_key_algorithm'];
    final publicKeySignature = json['signing_public_key_signature'];
    final publicKeySignatureAlgorithm =
        json['signing_public_key_signature_algorithm'];
    final publicKeySignaturePayload =
        json['signing_public_key_signature_payload'];
    if (signingPublicKey is! String ||
        signingPublicKey.trim().isEmpty ||
        signingPublicKeyId is! String ||
        signingPublicKeyId.trim().isEmpty ||
        signingPublicKeyAlgorithm is! String ||
        signingPublicKeyAlgorithm.trim().isEmpty ||
        publicKeySignature is! String ||
        publicKeySignature.trim().isEmpty ||
        publicKeySignatureAlgorithm is! String ||
        publicKeySignatureAlgorithm.trim().isEmpty ||
        publicKeySignaturePayload is! Map<String, dynamic>) {
      throw const FormatException(
        'Signing metadata is missing required fields.',
      );
    }

    return SigningMetadata(
      signingPublicKey: signingPublicKey.trim(),
      signingPublicKeyId: signingPublicKeyId.trim(),
      signingPublicKeyAlgorithm: signingPublicKeyAlgorithm.trim(),
      publicKeySignature: publicKeySignature.trim(),
      publicKeySignatureAlgorithm: publicKeySignatureAlgorithm.trim(),
      publicKeySignaturePayload: PublicKeySignaturePayload.fromJson(
        publicKeySignaturePayload,
      ),
    );
  }
}

class PublicKeySignaturePayload {
  const PublicKeySignaturePayload({
    required this.schemaVersion,
    required this.keyPurpose,
    required this.keyAlgorithm,
    required this.keyId,
    required this.publicKeyPem,
  });

  final int schemaVersion;
  final String keyPurpose;
  final String keyAlgorithm;
  final String keyId;
  final String publicKeyPem;

  factory PublicKeySignaturePayload.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'];
    final keyPurpose = json['key_purpose'];
    final keyAlgorithm = json['key_algorithm'];
    final keyId = json['key_id'];
    final publicKeyPem = json['public_key_pem'];
    if (schemaVersion is! int ||
        keyPurpose is! String ||
        keyPurpose.trim().isEmpty ||
        keyAlgorithm is! String ||
        keyAlgorithm.trim().isEmpty ||
        keyId is! String ||
        keyId.trim().isEmpty ||
        publicKeyPem is! String ||
        publicKeyPem.trim().isEmpty) {
      throw const FormatException(
        'Signing metadata payload is missing required fields.',
      );
    }

    return PublicKeySignaturePayload(
      schemaVersion: schemaVersion,
      keyPurpose: keyPurpose.trim(),
      keyAlgorithm: keyAlgorithm.trim(),
      keyId: keyId.trim(),
      publicKeyPem: publicKeyPem.trim(),
    );
  }
}
