import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;

// ─────────────────────────────────────────────────────────────────────────────
// EncryptionService — AES-256-CBC symmetric encryption for IMEI storage.
//
// Security note:
//   The key is compiled into the app binary. This provides at-rest protection
//   in Firestore (raw IMEI is never stored), but the key can be extracted by
//   someone with access to the APK/IPA + a decompiler. For this use-case
//   (shop management, not banking), this is an acceptable tradeoff.
//
// Key rotation: To rotate the key, update _rawKey below and re-save all
//   customer records (they will be re-encrypted). Keep a migration script.
// ─────────────────────────────────────────────────────────────────────────────
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  // AES-256 key: must be exactly 32 bytes (256 bits).
  // IMPORTANT: Do NOT commit production keys to source control.
  //            In production, inject this via --dart-define or a secrets file.
  static const String _rawKey = 'SPMobileRepair2026SecureKey!@#\$1'; // 32 chars

  // Fixed IV (Initialization Vector) — 16 bytes for AES-CBC.
  // Using a fixed IV is less secure than random-per-record IVs but simplifies
  // storage (no need to store IV alongside ciphertext). Acceptable for IMEI.
  static const String _rawIv = 'SP1MobileIV!2026'; // 16 chars

  late final enc.Key _key = enc.Key.fromUtf8(_rawKey);
  late final enc.IV _iv = enc.IV.fromUtf8(_rawIv);
  late final enc.Encrypter _encrypter =
      enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));

  /// Encrypts [plainText] and returns a Base64-encoded ciphertext string.
  String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypts a Base64 [cipherText] back to the original plain text.
  /// Throws [FormatException] if the input is not valid ciphertext.
  String decrypt(String cipherText) {
    if (cipherText.isEmpty) return '';
    final encrypted = enc.Encrypted(base64.decode(cipherText));
    return _encrypter.decrypt(encrypted, iv: _iv);
  }
}
