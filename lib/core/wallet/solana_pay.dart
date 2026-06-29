/// Solana Pay URL 构造（与 Web solana-pay.ts 一致）。
String buildPayUrl({
  required String recipient,
  String? amount,
  String? splToken,
  String? label,
  String? message,
}) {
  final params = <String, String>{};
  if (amount != null && amount.isNotEmpty) params['amount'] = amount;
  if (splToken != null && splToken.isNotEmpty) params['spl-token'] = splToken;
  if (label != null && label.isNotEmpty) params['label'] = label;
  if (message != null && message.isNotEmpty) params['message'] = message;
  final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return 'solana:$recipient${qs.isNotEmpty ? '?$qs' : ''}';
}
