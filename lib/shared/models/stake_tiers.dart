/// 质押档位与加速比例（口径与 Web lib/staking/constants.ts 一致）。
class StakeTier {
  final String id;
  final int amount;
  final double multiplier;
  final String label;
  final int staticDays;

  const StakeTier({
    required this.id,
    required this.amount,
    required this.multiplier,
    required this.label,
    required this.staticDays,
  });
}

const List<StakeTier> stakeTiers = [
  StakeTier(id: 'tier-100', amount: 100, multiplier: 2.0, label: '100 USTD (2倍)', staticDays: 200),
  StakeTier(id: 'tier-500', amount: 500, multiplier: 2.5, label: '500 USTD (2.5倍)', staticDays: 250),
  StakeTier(id: 'tier-1000', amount: 1000, multiplier: 2.5, label: '1000 USTD (2.5倍)', staticDays: 250),
  StakeTier(id: 'tier-3000', amount: 3000, multiplier: 3.0, label: '3000 USTD (3倍)', staticDays: 300),
  StakeTier(id: 'tier-5000', amount: 5000, multiplier: 3.0, label: '5000 USTD (3倍)', staticDays: 300),
  StakeTier(id: 'tier-10000', amount: 10000, multiplier: 3.0, label: '10000 USTD (3倍)', staticDays: 300),
];

const List<double> accelerationRates = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

const double dailyRate = 0.01;

double accelerationRateFor(int referrals) {
  if (referrals < 0) return 0;
  if (referrals > 5) return 1.0;
  return accelerationRates[referrals];
}
