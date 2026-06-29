import 'package:flutter/material.dart';

import 'package:sinpra_app/core/wallet/wallet_profiles.dart';

class WalletSourceGrid extends StatelessWidget {
  const WalletSourceGrid({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final WalletProfileId? selected;
  final ValueChanged<WalletProfileId> onSelect;

  static const _colors = {
    WalletProfileId.phantom: Color(0xFFAB9FF2),
    WalletProfileId.solflare: Color(0xFFFC7226),
    WalletProfileId.backpack: Color(0xFFE33E3F),
    WalletProfileId.tokenpocket: Color(0xFF2980FE),
    WalletProfileId.okx: Color(0xFF000000),
  };

  static String _abbr(WalletProfileId id) {
    switch (id) {
      case WalletProfileId.phantom:
        return 'Ph';
      case WalletProfileId.solflare:
        return 'Sf';
      case WalletProfileId.backpack:
        return 'Bp';
      case WalletProfileId.tokenpocket:
        return 'TP';
      case WalletProfileId.okx:
        return 'OKX';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        for (final p in walletProfiles)
          Material(
            color: selected == p.id ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(p.id),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == p.id
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: selected == p.id ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _colors[p.id] ?? Colors.grey,
                      child: Text(
                        _abbr(p.id),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Solana', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
