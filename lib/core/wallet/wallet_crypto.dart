import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 与 Web 端 embedded-wallet/crypto.ts 完全兼容的加密模块：
/// PBKDF2(SHA-256, 250000) 派生密钥 + AES-GCM 加解密。
/// 私钥/助记词永远不以明文离开本机；服务端只存密文备份。
///
/// 密文格式与 Web 一致：{ v: 1, salt: base64, iv: base64, data: base64 }
/// - salt：PBKDF2 派生密钥用的盐（随机 16 字节）
/// - iv：AES-GCM 的 nonce（随机 12 字节）
/// - data：base64( cipherText || mac(16) )，与 Web subtle.encrypt 输出顺序一致
class EncryptedBlob {
  final int v;
  final String salt;
  final String iv;
  final String data;

  const EncryptedBlob({
    this.v = 1,
    required this.salt,
    required this.iv,
    required this.data,
  });

  Map<String, dynamic> toJson() => {'v': v, 'salt': salt, 'iv': iv, 'data': data};

  factory EncryptedBlob.fromJson(Map<String, dynamic> j) => EncryptedBlob(
        v: (j['v'] as num?)?.toInt() ?? 1,
        salt: j['salt'] as String,
        iv: j['iv'] as String,
        data: j['data'] as String,
      );

  String toJsonString() => jsonEncode(toJson());

  static EncryptedBlob? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return EncryptedBlob.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 解析服务端 encrypted_blob（可能是 JSON 字符串或已解析对象）。
  static EncryptedBlob? fromServerValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      try {
        return EncryptedBlob.fromJson(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is String) return fromJsonString(raw);
    return null;
  }
}

const int _pbkdf2Iterations = 250000;
const int _saltBytes = 16;
const int _ivBytes = 12;

String _toBase64(List<int> bytes) => base64.encode(bytes);
Uint8List _fromBase64(String b64) => Uint8List.fromList(base64.decode(b64));

Future<SecretKey> _deriveKey(String pin, Uint8List salt) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );
  final derived = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(pin)),
    nonce: salt,
  );
  return derived;
}

/// 用 PIN 加密明文，返回与 Web 兼容的密文对象。
Future<EncryptedBlob> encryptSecret(String plaintext, String pin) async {
  final cipher = AesGcm.with256bits();
  final salt = await _secureBytes(_saltBytes);
  final iv = await _secureBytes(_ivBytes);
  final secretKey = await _deriveKey(pin, salt);
  final secretBox = await cipher.encrypt(
    utf8.encode(plaintext),
    secretKey: secretKey,
    nonce: iv,
  );
  return EncryptedBlob(
    salt: _toBase64(salt),
    iv: _toBase64(iv),
    data: _toBase64(secretBox.concatenation(nonce: false, mac: true)),
  );
}

/// 用 PIN 解密密文对象，PIN 错误会抛出 SecretBoxAuthenticationError。
Future<String> decryptSecret(EncryptedBlob blob, String pin) async {
  final cipher = AesGcm.with256bits();
  final salt = _fromBase64(blob.salt);
  final iv = _fromBase64(blob.iv);
  final combined = _fromBase64(blob.data);
  final secretKey = await _deriveKey(pin, salt);
  // combined = cipherText(前 N-16) || mac(后 16)
  final mac = Mac(combined.sublist(combined.length - 16));
  final cipherText = combined.sublist(0, combined.length - 16);
  final secretBox = SecretBox(cipherText, nonce: iv, mac: mac);
  final plain = await cipher.decrypt(secretBox, secretKey: secretKey);
  return utf8.decode(plain);
}

Future<Uint8List> _secureBytes(int length) async {
  final r = SecureRandom.fast;
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = r.nextInt(256);
  }
  return bytes;
}
