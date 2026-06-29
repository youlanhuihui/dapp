import '../models/stake_tiers.dart';

/// 模拟器计算结果（口径与 Web lib/staking/calculator.ts 一致）。
class SimulationResult {
  final double baseDaily;
  final double accelerationRate;
  final double referralAccelerationDaily;
  final double totalDaily;
  final double contractTotal;
  final double completionDays;
  final double annualReinvestProfit;
  final double roiMultiplier;

  const SimulationResult({
    required this.baseDaily,
    required this.accelerationRate,
    required this.referralAccelerationDaily,
    required this.totalDaily,
    required this.contractTotal,
    required this.completionDays,
    required this.annualReinvestProfit,
    required this.roiMultiplier,
  });
}

SimulationResult runSimulation(
  StakeTier tier,
  int directReferrals,
  List<int> referralStakesOverride,
) {
  final accelRate = accelerationRateFor(directReferrals);
  final referralStakes = referralStakesOverride;
  final baseDaily = tier.amount * dailyRate;
  double accel = 0;
  for (var i = 0; i < directReferrals && i < referralStakes.length; i++) {
    accel += referralStakes[i] * dailyRate * accelRate;
  }
  final totalDaily = baseDaily + accel;
  final contractTotal = tier.amount * tier.multiplier;
  final completionDays = totalDaily > 0 ? contractTotal / totalDaily : 0;
  final singleNet = contractTotal - tier.amount;
  final annualCount = completionDays > 0 ? 365 / completionDays : 0;
  final annualProfit = annualCount * singleNet;
  final roi = tier.amount > 0 ? annualProfit / tier.amount : 0;

  return SimulationResult(
    baseDaily: baseDaily,
    accelerationRate: accelRate,
    referralAccelerationDaily: accel,
    totalDaily: totalDaily,
    contractTotal: contractTotal,
    completionDays: completionDays.toDouble(),
    annualReinvestProfit: annualProfit.toDouble(),
    roiMultiplier: roi.toDouble(),
  );
}

String formatAmount(num n, [int decimals = 2]) {
  return n.toStringAsFixed(decimals);
}
