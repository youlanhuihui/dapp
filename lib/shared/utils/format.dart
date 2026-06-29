/// Solana 地址短显：abc...xyz
String shortenAddress(String addr, [int n = 4]) {
  if (addr.length <= n * 2 + 3) return addr;
  return '${addr.substring(0, n)}...${addr.substring(addr.length - n)}';
}

/// 解析金额字符串为整数的最小单位（lamports / token 最小单位）
int parseAmountToUnits(String amount, int decimals) {
  final n = double.tryParse(amount) ?? 0;
  return (n * _pow10(decimals)).round();
}

int _pow10(int e) {
  var r = 1;
  for (var i = 0; i < e; i++) {
    r *= 10;
  }
  return r;
}

String formatTokenAmount(num uiAmount, {int maximumFractionDigits = 6}) {
  if (uiAmount == 0) return '0';
  return uiAmount.toStringAsFixed(maximumFractionDigits).replaceAll(RegExp(r'\.?0+$'), '');
}
