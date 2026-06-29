import 'package:flutter/material.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';

/// 生态卡片发送面板：点击后等待异步发送完成再关闭。
class EcosystemSheet extends StatefulWidget {
  final List<Map<String, dynamic>> presets;
  final bool loading;
  final Future<void> Function(Map<String, dynamic> preset) onSend;

  const EcosystemSheet({
    super.key,
    required this.presets,
    required this.loading,
    required this.onSend,
  });

  @override
  State<EcosystemSheet> createState() => _EcosystemSheetState();
}

class _EcosystemSheetState extends State<EcosystemSheet> {
  bool _sending = false;
  String? _sendingKey;

  Future<void> _send(Map<String, dynamic> p) async {
    final key = p['kind'] as String? ?? p['mini_app_id'] as String? ?? '';
    setState(() { _sending = true; _sendingKey = key; });
    try {
      await widget.onSend(p);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() { _sending = false; _sendingKey = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('ecosystem'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _sending ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            if (widget.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (widget.presets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(context.tr('empty'),
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              )
            else
              ...widget.presets.map((p) => _presetTile(p)),
          ],
        ),
      ),
    );
  }

  String _actionLabel(Map<String, dynamic> p) {
    final kind = p['kind'] as String?;
    if (kind == 'staking' || kind == 'node') return '发送我的推广';
    return p['action_label'] as String? ?? '发送';
  }

  Widget _presetTile(Map<String, dynamic> p) {
    final title = p['title'] as String? ?? '';
    final desc = p['description'] as String? ?? '';
    final action = _actionLabel(p);
    final key = p['kind'] as String? ?? p['mini_app_id'] as String? ?? title;
    final busy = _sending && _sendingKey == key;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: SinpraTheme.brand50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.apps, color: SinpraTheme.brand600),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: desc.isEmpty
          ? null
          : Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: busy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(
              onPressed: _sending ? null : () => _send(p),
              child: Text(action),
            ),
    );
  }
}
