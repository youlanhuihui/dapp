import 'dart:convert';
import 'dart:typed_data';

import 'package:solana/base58.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:solana/solana.dart';

import 'wallet_profiles.dart';

class PreviewImportResult {
  PreviewImportResult._({
    required this.ok,
    this.address,
    this.secretType,
    this.pathUsed,
    this.warnings = const [],
    this.code,
    this.message,
  });

  final bool ok;
  final String? address;
  final String? secretType;
  final String? pathUsed;
  final List<String> warnings;
  final String? code;
  final String? message;

  factory PreviewImportResult.success({
    required String address,
    required String secretType,
    required String pathUsed,
    List<String> warnings = const [],
  }) =>
      PreviewImportResult._(
        ok: true,
        address: address,
        secretType: secretType,
        pathUsed: pathUsed,
        warnings: warnings,
      );

  factory PreviewImportResult.failure({
    required String code,
    required String message,
  }) =>
      PreviewImportResult._(ok: false, code: code, message: message);
}

/// 嵌入式钱包核心：BIP39 + 多格式私钥 + 多钱包派生路径。
class WalletKeys {
  static String solanaPath(int index) => "m/44'/501'/$index'/0'";

  static String generateMnemonic() => bip39.generateMnemonic();

  static String normalizeSecretInput(String input) {
    var v = input.replaceAll('\u3000', ' ').trim();
    final words = v.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 12) return words.join(' ');
    return v.replaceAll(RegExp(r'[\r\n\s]+'), '');
  }

  static bool validateMnemonic(String mnemonic) =>
      bip39.validateMnemonic(normalizeSecretInput(mnemonic));

  static Uint8List? parseSecretBytes(String input) {
    final v = normalizeSecretInput(input);
    if (v.isEmpty) return null;

    if (v.startsWith('[')) {
      try {
        final arr = jsonDecode(v);
        if (arr is List &&
            arr.isNotEmpty &&
            arr.every((n) => n is int && n >= 0 && n <= 255)) {
          final bytes = Uint8List.fromList(arr.cast<int>());
          if (bytes.length == 32 || bytes.length == 64) return bytes;
        }
      } catch (_) {}
    }

    final hexPattern = RegExp(r'^(0x)?[0-9a-fA-F]+$');
    if (hexPattern.hasMatch(v)) {
      final hex = v.startsWith('0x') ? v.substring(2) : v;
      if (hex.length == 64 || hex.length == 128) {
        final bytes = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < bytes.length; i++) {
          bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return bytes;
      }
    }

    try {
      final decoded = base58decode(v);
      if (decoded.length == 32 || decoded.length == 64) {
        return Uint8List.fromList(decoded);
      }
    } catch (_) {}

    return null;
  }

  static Future<Ed25519HDKeyPair> keypairFromSecretBytes(Uint8List bytes) async {
    // Solana 钱包导出的 64 字节 = 32 字节 seed + 32 字节公钥（Phantom/TP 常见 base58 约 88 字符）
    if (bytes.length == 64) {
      final seed = Uint8List.fromList(bytes.sublist(0, 32));
      return Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: seed);
    }
    if (bytes.length == 32) {
      return Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: bytes);
    }
    throw Exception('私钥长度无效（${bytes.length} 字节，Solana 需 32 或 64 字节）');
  }

  /// 私钥无法解析时给出更具体的提示（截断、空格、错误长度等）。
  static String describePrivateKeyParseFailure(String input) {
    final normalized = normalizeSecretInput(input);
    if (normalized.isEmpty) {
      return '请输入助记词或私钥';
    }
    if (normalized.split(RegExp(r'\s+')).length >= 12) {
      return '无法识别私钥格式。请确认从 Solana 钱包导出，支持 base58、hex 或 JSON 数组。勿粘贴钱包地址。';
    }

    final hadInternalSpace = RegExp(r'\s').hasMatch(input.trim());
    if (hadInternalSpace) {
      return '私钥中检测到空格或换行，可能导致内容损坏。'
          '请从 TokenPocket 一次性全选复制，确保约 88 个连续字符（中间无空格）。'
          '合并后当前 ${normalized.length} 字符。';
    }

    if (normalized.startsWith('[')) {
      try {
        final arr = jsonDecode(normalized);
        if (arr is List) {
          return 'JSON 私钥数组长度为 ${arr.length}，Solana 需 32 或 64 个数字。'
              '请确认从 Solana 钱包完整导出。';
        }
      } catch (_) {}
    }

    final hexPattern = RegExp(r'^(0x)?[0-9a-fA-F]+$');
    if (hexPattern.hasMatch(normalized)) {
      final hex = normalized.startsWith('0x') ? normalized.substring(2) : normalized;
      return 'hex 私钥长度为 ${hex.length} 个十六进制字符，Solana 需 64（32 字节）或 128（64 字节）。';
    }

    try {
      final decoded = base58decode(normalized);
      if (decoded.length != 32 && decoded.length != 64) {
        return '私钥不完整或格式错误：解码为 ${decoded.length} 字节（Solana 需 32 或 64 字节）。'
            'TokenPocket/Phantom 导出通常为约 88 个连续字符；当前 ${normalized.length} 字符。'
            '请重新完整复制，勿截断。';
      }
    } catch (_) {
      return '私钥 base58 无法解码，请检查是否完整复制、勿粘贴钱包地址。'
          '当前 ${normalized.length} 字符。';
    }

    return '无法识别私钥格式。请确认从 Solana 钱包导出，支持 base58、hex 或 JSON 数组。勿粘贴钱包地址。';
  }

  static Future<Ed25519HDKeyPair> keypairFromMnemonicWithPath(
    String mnemonic,
    String path,
  ) async {
    final normalized = normalizeSecretInput(mnemonic);
    final seed = bip39.mnemonicToSeed(normalized);
    final derived = await ED25519_HD_KEY.derivePath(path, seed);
    return Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: Uint8List.fromList(derived.key),
    );
  }

  static Future<Ed25519HDKeyPair> keypairFromMnemonic(
    String mnemonic, {
    int account = 0,
    String? pathOverride,
  }) async {
    final path = pathOverride ?? solanaPath(account);
    return keypairFromMnemonicWithPath(mnemonic, path);
  }

  static Future<Ed25519HDKeyPair> keypairFromSecret(String input) async {
    final bytes = parseSecretBytes(input);
    if (bytes == null) throw Exception('私钥格式无效');
    return keypairFromSecretBytes(bytes);
  }

  static String detectSecretType(String input) {
    final v = normalizeSecretInput(input);
    if (v.isEmpty) return 'invalid';
    if (v.split(RegExp(r'\s+')).length >= 12) {
      return validateMnemonic(v) ? 'mnemonic' : 'invalid';
    }
    return parseSecretBytes(v) != null ? 'secret' : 'invalid';
  }

  static Future<String> secretToBase58(Ed25519HDKeyPair kp) async {
    final data = await kp.extract();
    return base58encode(data.bytes);
  }

  static Future<PreviewImportResult> previewImport({
    required String secret,
    required WalletProfileId walletId,
    String? pathId,
  }) async {
    final normalized = normalizeSecretInput(secret);
    if (normalized.isEmpty) {
      return PreviewImportResult.failure(
        code: 'INVALID_FORMAT',
        message: '请输入助记词或私钥',
      );
    }

    final pathOpt = getDerivationPath(walletId, pathId: pathId);
    final warnings = <String>[];

    if (normalized.split(RegExp(r'\s+')).length >= 12) {
      if (!validateMnemonic(normalized)) {
        return PreviewImportResult.failure(
          code: 'INVALID_MNEMONIC',
          message: '助记词无效，请检查单词拼写、顺序和词数（12/24）',
        );
      }
      final kp = await keypairFromMnemonicWithPath(normalized, pathOpt.path);
      if (pathOpt.id != 'default') {
        warnings.add('使用路径：${pathOpt.label}');
      }
      return PreviewImportResult.success(
        address: kp.address,
        secretType: 'mnemonic',
        pathUsed: pathOpt.path,
        warnings: warnings,
      );
    }

    final bytes = parseSecretBytes(normalized);
    if (bytes == null) {
      return PreviewImportResult.failure(
        code: 'INVALID_FORMAT',
        message: describePrivateKeyParseFailure(secret),
      );
    }

    try {
      final kp = await keypairFromSecretBytes(bytes);
      return PreviewImportResult.success(
        address: kp.address,
        secretType: 'secret',
        pathUsed: pathOpt.path,
        warnings: warnings,
      );
    } catch (e) {
      return PreviewImportResult.failure(
        code: 'INVALID_SECRET',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
