import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sinpra_app/app/theme.dart';
import 'package:sinpra_app/core/i18n/app_i18n.dart';
import 'package:sinpra_app/core/ui/app_snackbar.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/shared/models/staking.dart';
import 'package:sinpra_app/shared/models/stake_tiers.dart';
import 'package:sinpra_app/shared/services/staking_service.dart';
import 'package:sinpra_app/shared/utils/format.dart';
import 'package:sinpra_app/shared/utils/stake_calculator.dart';
import 'package:sinpra_app/modules/business/services/staking_on_chain.dart';

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

enum BizTab { overview, stake, simulator, node, withdraw }

class _BusinessScreenState extends State<BusinessScreen> {
  late final StakingService _svc;
  late final StakingOnChain _onChain;
  BizTab _tab = BizTab.overview;
  StakingConfig? _config;
  Overview? _overview;
  NodeConfig? _nodeConfig;
  NodeMe? _nodeMe;
  List<PayoutBalance> _payouts = [];
  double _ustdBalance = 0;
  bool _busy = false;
  String? _phase;
  String? _error;
  String? _toast;

  // stake
  String _tierId = 'tier-1000';
  // simulator
  String _simTierId = 'tier-100';
  int _simRefCount = 5;
  List<String> _simRefTierIds = ['tier-1000','tier-1000','tier-1000','tier-1000','tier-1000'];
  // withdraw
  String _withdrawAmount = '';
  String _withdrawAddress = '';
  final Map<String, _PayoutForm> _payoutForm = {};

  @override
  void initState() {
    super.initState();
    _svc = StakingService(context.read());
    _onChain = StakingOnChain(context.read<EmbeddedWalletStore>());
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadConfig(), _loadOverview(), _loadNode(), _loadPayouts(), _loadBalance(),
    ]);
  }

  Future<void> _loadConfig() async {
    try {
      _config = await _svc.getConfig();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadOverview() async {
    try {
      _overview = await _svc.getOverview();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadNode() async {
    try {
      _nodeConfig = await _svc.getNodeConfig();
      _nodeMe = await _svc.getNodeMe();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadPayouts() async {
    try {
      _payouts = await _svc.getPayoutBalances();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadBalance() async {
    final w = context.read<EmbeddedWalletStore>();
    final addr = w.activeAddress;
    if (addr == null || addr.isEmpty || _config?.mint == null) return;
    try {
      // 查 SPL token 余额：简化用 get TokenAccountsByOwner 不可行，这里读 SOL 余额占位
      // 真实 USTD 余额需查 ATA；保留接口，先取 SOL
      _ustdBalance = await w.getSolBalance(addr);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  String get _sym => _config?.symbol ?? 'USTD';
  int get _decimals => _config?.decimals ?? 6;

  void _showToast(String msg) {
    setState(() => _toast = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _handleStake() async {
    final wallet = context.read<EmbeddedWalletStore>();
    if (!wallet.isUnlocked) {
      AppSnackBar.showErrorText(context, context.tr('bizConnectFirst'));
      return;
    }
    final tier = stakeTiers.firstWhere((t) => t.id == _tierId);
    setState(() { _busy = true; _error = null; });
    try {
      final sig = await _onChain.transferToPool(
        config: _config,
        nodeConfig: null,
        amount: tier.amount.toDouble(),
        decimals: _decimals,
        mintStr: _config!.mint!,
        poolAddress: _config!.poolAddress,
        onProgress: (p) => setState(() => _phase = p == 'confirm' ? context.tr('bizPhaseRecord') : context.tr('bizPhaseTransfer')),
      );
      await _svc.submitStake(address: wallet.activeAddress!, amount: tier.amount.toString(), depositTx: sig);
      _showToast(context.tr('bizStakeSuccess'));
      setState(() => _tab = BizTab.overview);
      await _loadAll();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _busy = false; _phase = null; });
    }
  }

  Future<void> _handleBuyNode() async {
    final wallet = context.read<EmbeddedWalletStore>();
    if (!wallet.isUnlocked || _nodeConfig == null) {
      AppSnackBar.showErrorText(context, context.tr('bizConnectFirst'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('nodeTitle')),
        content: Text(context.trArg('nodeConfirmBuy', {'price': _nodeConfig!.price})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text(context.tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(_, true), child: Text(context.tr('confirm'))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      final sig = await _onChain.transferToPool(
        config: null,
        nodeConfig: _nodeConfig,
        amount: double.parse(_nodeConfig!.price),
        decimals: _nodeConfig!.decimals,
        mintStr: _nodeConfig!.mint!,
        poolAddress: _nodeConfig!.poolAddress!,
        onProgress: (p) => setState(() => _phase = p == 'confirm' ? context.tr('bizPhaseRecord') : context.tr('bizPhaseTransfer')),
      );
      await _svc.purchaseNode(address: wallet.activeAddress!, depositTx: sig);
      _showToast(context.tr('nodeBuySuccess'));
      await _loadAll();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _busy = false; _phase = null; });
    }
  }

  Future<void> _handleWithdraw() async {
    final amt = double.tryParse(_withdrawAmount) ?? 0;
    final withdrawable = double.parse(_overview?.withdrawable ?? '0');
    if (amt <= 0 || amt > withdrawable) {
      setState(() => _error = context.tr('bizWithdrawable'));
      return;
    }
    final addr = _withdrawAddress.trim().isEmpty
        ? context.read<EmbeddedWalletStore>().activeAddress
        : _withdrawAddress.trim();
    if (addr == null || addr.isEmpty) {
      setState(() => _error = context.tr('withdrawEnterAddress'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _svc.submitWithdraw(address: addr, amount: amt.toString());
      _showToast(context.tr('withdrawSubmitted'));
      setState(() => _withdrawAmount = '');
      await _loadOverview();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePayoutWithdraw(String business, int slot, String max) async {
    final key = '$business:$slot';
    final form = _payoutForm[key] ?? _PayoutForm();
    final amt = double.tryParse(form.amount) ?? 0;
    final addr = (form.address.isEmpty
            ? context.read<EmbeddedWalletStore>().activeAddress
            : form.address)
        ?.trim();
    if (amt <= 0 || amt > double.parse(max)) {
      setState(() => _error = context.tr('bizWithdrawable'));
      return;
    }
    if (addr == null || addr.isEmpty) {
      setState(() => _error = context.tr('withdrawEnterAddress'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _svc.submitPayoutWithdraw(business: business, slot: slot, amount: amt.toString(), address: addr);
      _showToast(context.tr('withdrawSubmitted'));
      setState(() => _payoutForm[key] = _PayoutForm(address: addr));
      await _loadPayouts();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SinpraTheme.slate950,
      body: Stack(children: [
        SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _hero(),
                const SizedBox(height: 12),
                _tabBar(),
                const SizedBox(height: 12),
                if (_error != null) _errorBox(),
                ..._tabContent(),
              ],
            ),
          ),
        ),
        if (_toast != null) _toastView(),
      ]),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SinpraTheme.brand900, SinpraTheme.slate900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('bizCenterTag'),
                    style: const TextStyle(color: SinpraTheme.brand300, fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                const Text('SINPRA DAPP',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
            ),
            GestureDetector(
              onTap: () => context.push('/settings/wallet'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: SinpraTheme.brand800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SinpraTheme.brand400.withOpacity(0.3)),
                ),
                child: Text(
                  context.read<EmbeddedWalletStore>().isUnlocked
                      ? context.tr('bizBalUstd')
                      : context.tr('bizConnectWallet'),
                  style: const TextStyle(color: SinpraTheme.brand200, fontSize: 12),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(context.tr('bizHeroDesc'),
              style: const TextStyle(color: SinpraTheme.slate300, fontSize: 12, height: 1.5)),
          const SizedBox(height: 16),
          Row(children: [
            _heroStat(context.tr('bizBalUstd'), '${formatAmount(_ustdBalance)} $_sym'),
            const SizedBox(width: 10),
            _heroStat(context.tr('bizTotalStaked'), '${_overview?.totalStaked ?? '0'} $_sym'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _heroStat(context.tr('bizWithdrawable'), '${_overview?.withdrawable ?? '0'} $_sym', accent: SinpraTheme.emerald300),
            const SizedBox(width: 10),
            _heroStat(context.tr('bizEstEarnings'), '${_overview?.totalContract ?? '0'} $_sym', accent: SinpraTheme.amber300),
          ]),
          if (_config != null) ...[
            const SizedBox(height: 10),
            Text(
              '${context.tr('bizDailyRate')} ${(_config!.dailyRateBps / 100).toStringAsFixed(2)}% · ${context.tr('bizFeeLabel')} ${_config!.withdrawFeePercent}% · ${context.tr('bizMinStake')} ${_config!.minStake} $_sym',
              style: const TextStyle(color: SinpraTheme.slate400, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, {Color accent = Colors.white}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: SinpraTheme.slate400, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _tabBar() {
    final tabs = [
      (BizTab.overview, context.tr('bizTabOverview')),
      (BizTab.stake, context.tr('bizTabStake')),
      (BizTab.simulator, context.tr('bizTabSimulator')),
      (BizTab.node, context.tr('bizTabNode')),
      (BizTab.withdraw, context.tr('bizTabWithdraw')),
    ];
    return Wrap(
      spacing: 8,
      children: tabs.map((t) {
        final selected = _tab == t.$1;
        return GestureDetector(
          onTap: () => setState(() { _tab = t.$1; _error = null; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? SinpraTheme.brand600 : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(t.$2,
                style: TextStyle(
                  color: selected ? Colors.white : SinpraTheme.slate400,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _errorBox() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SinpraTheme.red300.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SinpraTheme.red300.withOpacity(0.3)),
        ),
        child: Text(_error!, style: const TextStyle(color: SinpraTheme.red300, fontSize: 13)),
      );

  List<Widget> _tabContent() {
    switch (_tab) {
      case BizTab.overview:
        return _overviewTab();
      case BizTab.stake:
        return _stakeTab();
      case BizTab.simulator:
        return _simulatorTab();
      case BizTab.node:
        return _nodeTab();
      case BizTab.withdraw:
        return _withdrawTab();
    }
  }

  // ── Overview ─────────────────────────────
  List<Widget> _overviewTab() {
    final ov = _overview;
    return [
      if (ov != null && (ov.referralCount > 0 || ov.stakes.isNotEmpty)) ...[
        _darkCard([
          Text(context.tr('bizMyAccel'), style: _h2),
          const SizedBox(height: 4),
          Text(context.tr('bizAccelTip'), style: _hint),
          const SizedBox(height: 12),
          _accelBar(ov.accelRatioPct, '${context.tr('bizRefCount')}：${ov.referralCount}/${ov.maxReferrals} ${context.tr('bizPeople')}'),
          const SizedBox(height: 12),
          Row(children: [
            _miniStat(context.tr('bizRefereeStaked'), '${ov.referralStaked} $_sym'),
            _miniStat(context.tr('bizBaseDaily'), '${ov.baseDaily} $_sym'),
            _miniStat(context.tr('bizAccelDaily'), '${ov.accelDaily} $_sym', accent: SinpraTheme.emerald300),
            _miniStat(context.tr('bizTotalDailyNow'), '${ov.totalDaily} $_sym', accent: SinpraTheme.amber300),
          ]),
        ]),
        const SizedBox(height: 12),
      ],
      GestureDetector(
        onTap: () => context.push('/settings/referral'),
        child: _darkCard([
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('bizInviteFriends'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(context.tr('bizInviteDesc'), style: _hint),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: SinpraTheme.brand600, borderRadius: BorderRadius.circular(8)),
              child: Text('${context.tr('bizInviteGo')} ›', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      _darkCard([
        Text(context.tr('bizMyContracts'), style: _h2),
        const SizedBox(height: 8),
        if (ov == null || ov.stakes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text(context.tr('bizNoContracts'), style: _hint)),
          )
        else
          ...ov.stakes.map(_stakeItem),
      ]),
    ];
  }

  Widget _stakeItem(StakeItem s) {
    final completed = s.status == 'completed';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: completed ? SinpraTheme.emerald500.withOpacity(0.08) : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: completed ? SinpraTheme.emerald500.withOpacity(0.3) : Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${s.principal} $_sym', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: completed ? SinpraTheme.emerald500.withOpacity(0.2) : SinpraTheme.brand500.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(completed ? context.tr('bizCompleted') : context.tr('bizReleasing'),
                style: TextStyle(color: completed ? SinpraTheme.emerald300 : SinpraTheme.brand200, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${s.multiplier}x · ${context.tr('bizContractTotal')} ${s.contractTotal}', style: _hint)),
          Text('${context.tr('bizReleased')} ${s.released}', style: _hint),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (s.progress / 100).clamp(0, 1),
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(SinpraTheme.emerald400),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text('${context.tr('bizContractProgress')} ${s.progress.toStringAsFixed(1)}%', style: _hint),
        ),
      ]),
    );
  }

  Widget _accelBar(int pct, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _hint),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(SinpraTheme.emerald400),
            ),
          ),
        ],
      );

  // ── Stake ─────────────────────────────
  List<Widget> _stakeTab() {
    final tier = stakeTiers.firstWhere((t) => t.id == _tierId);
    final dailyRate = (_config?.dailyRateBps ?? 100) / 10000;
    final contractTotal = tier.amount * tier.multiplier;
    final dailyRelease = tier.amount * dailyRate;
    final completionDays = dailyRelease > 0 ? contractTotal / dailyRelease : 0.0;
    return [
      _darkCard([
        Text(context.tr('bizSelectTier'), style: _h2),
        const SizedBox(height: 4),
        Text(context.tr('bizParamHint'), style: _hint),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stakeTiers.map((t) {
            final selected = t.id == _tierId;
            return GestureDetector(
              onTap: () => setState(() => _tierId = t.id),
              child: Container(
                width: 100,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? SinpraTheme.brand600.withOpacity(0.3) : Colors.black.withOpacity(0.2),
                  border: Border.all(color: selected ? SinpraTheme.brand400 : Colors.white10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t.amount} $_sym', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${t.multiplier}x', style: const TextStyle(color: SinpraTheme.emerald300, fontSize: 12)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _row(context.tr('bizTierMultiplier'), '${tier.multiplier}x', accent: SinpraTheme.emerald400),
        _row(context.tr('bizContractTotal'), '${formatAmount(contractTotal, 0)} $_sym'),
        _row(context.tr('bizBaseDaily'), '${formatAmount(dailyRelease)} $_sym'),
        _row(context.tr('bizEstCompletion'), '${formatAmount(completionDays, 1)} ${context.tr('bizDays')}'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _handleStake,
            child: _busy
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_phase ?? context.tr('bizStakeReal')),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(context.tr('bizStakeFooterSlogan'), style: _hint, textAlign: TextAlign.center),
        ),
      ]),
    ];
  }

  // ── Simulator ─────────────────────────────
  List<Widget> _simulatorTab() {
    final tier = stakeTiers.firstWhere((t) => t.id == _simTierId);
    final refStakes = _simRefTierIds
        .sublist(0, _simRefCount)
        .map((id) => stakeTiers.firstWhere((t) => t.id == id).amount)
        .toList();
    final sim = runSimulation(tier, _simRefCount, refStakes);
    final accelPct = ((sim.accelerationRate) * 100).round();
    return [
      _darkCard([
        Text(context.tr('bizTabSimulator'), style: _h2),
        const SizedBox(height: 4),
        Text(context.tr('bizSimHint'), style: _hint),
        const SizedBox(height: 12),
        _tierDropdown(context.tr('bizOwnStake'), _simTierId, (v) => setState(() => _simTierId = v)),
        const SizedBox(height: 12),
        Text('${context.tr('bizRefCount')}：$_simRefCount ${context.tr('bizPeople')}', style: _hint),
        const SizedBox(height: 6),
        Row(
          children: List.generate(6, (n) {
            final selected = _simRefCount == n;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _simRefCount = n),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? SinpraTheme.brand600 : Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$n',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: selected ? Colors.white : SinpraTheme.slate400)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _simRefCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _tierDropdown(
              context.trArg('bizRefereeStakeN', {'n': '${i + 1}'}),
              _simRefTierIds[i],
              (v) => setState(() {
                final next = List<String>.from(_simRefTierIds);
                next[i] = v;
                _simRefTierIds = next;
              }),
            ),
          ),
        const SizedBox(height: 8),
        _accelBar(accelPct, context.tr('bizAccelProgressLabel')),
      ]),
      const SizedBox(height: 12),
      _darkCard([
        Text(context.tr('bizProjection'), style: _h2),
        const SizedBox(height: 12),
        Row(children: [
          _miniStat(context.tr('bizDailyTotal'), '${formatAmount(sim.totalDaily)} $_sym', accent: SinpraTheme.amber300),
          _miniStat(context.tr('bizEstCompletion'), '${formatAmount(sim.completionDays, 1)} ${context.tr('bizDays')}'),
          _miniStat(context.tr('bizReinvestCount'), '${formatAmount(sim.completionDays > 0 ? 365 / sim.completionDays : 0, 1)} ${context.tr('bizPerYear')}'),
          _miniStat(context.tr('bizRoi'), '${sim.roiMultiplier.toStringAsFixed(1)}x', accent: SinpraTheme.violet300),
        ]),
        const SizedBox(height: 12),
        _row(context.tr('bizBaseDaily'), '${formatAmount(sim.baseDaily)} $_sym'),
        _row('${context.tr('bizReferralAccel')}（$accelPct%）', '${formatAmount(sim.referralAccelerationDaily)} $_sym', accent: SinpraTheme.emerald400),
        _row(context.tr('bizContractTotal'), '${formatAmount(sim.contractTotal, 0)} $_sym'),
        _row(context.tr('bizNetSingle'), '${formatAmount(sim.contractTotal - tier.amount, 0)} $_sym'),
        _row(context.tr('bizNetAnnual'), '${formatAmount(sim.annualReinvestProfit, 0)} $_sym', accent: SinpraTheme.emerald400),
      ]),
    ];
  }

  Widget _tierDropdown(String label, String value, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _hint),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          dropdownColor: SinpraTheme.slate900,
          items: stakeTiers
              .map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text('${t.amount} $_sym · ${t.multiplier}x', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    ]);
  }

  // ── Node ─────────────────────────────
  List<Widget> _nodeTab() {
    final nc = _nodeConfig;
    final nm = _nodeMe;
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0x33F59E0B), Color(0x1AFBBF24)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SinpraTheme.gold400.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(context.tr('nodeTitle'), style: const TextStyle(color: SinpraTheme.amber300, fontSize: 16, fontWeight: FontWeight.bold)),
            if (nm?.isNodeVip == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SinpraTheme.gold400.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SinpraTheme.gold400.withOpacity(0.4)),
                ),
                child: Text('👑 ${context.tr('nodeVipBadge')}',
                    style: const TextStyle(color: SinpraTheme.amber300, fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 10),
          if (nc?.descriptionText.isNotEmpty == true) ...[
            Text(nc!.descriptionText, style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
          ],
          Row(children: [
            _miniStat(context.tr('nodeProgress'), '${nc?.soldCount ?? 0} / ${nc?.maxNodes ?? 1000}', accent: SinpraTheme.amber300),
            _miniStat(context.tr('nodePrice'), '${nc?.price ?? '300'} ${nc?.symbol ?? 'USTD'}', accent: SinpraTheme.emerald300),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ((nc?.soldCount ?? 0) / ((nc?.maxNodes ?? 1000).clamp(1, 999999))).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(SinpraTheme.gold400),
            ),
          ),
          const SizedBox(height: 16),
          if (nm?.purchased == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SinpraTheme.gold400.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SinpraTheme.gold400.withOpacity(0.3)),
              ),
              child: Center(child: Text('👑 ${context.tr('nodePurchased')}', style: const TextStyle(color: SinpraTheme.amber300, fontSize: 13))),
            )
          else if (nc?.soldOut == true)
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: null, child: Text(context.tr('nodeSoldOut'))))
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SinpraTheme.gold500,
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy ? null : _handleBuyNode,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_phase ?? context.tr('nodeBuy')),
              ),
            ),
          const SizedBox(height: 8),
          Center(child: Text(context.tr('nodeOnlyOnce'), style: _hint)),
          Center(child: Text(context.tr('bizStakeFooterSlogan'), style: _hint, textAlign: TextAlign.center)),
        ]),
      ),
      if (nm?.purchased == true) ...[
        const SizedBox(height: 12),
        _darkCard([
          Text(context.tr('nodeDividends'), style: _h2),
          const SizedBox(height: 8),
          if ((nm!.dividends.where((d) => double.parse(d.amount) > 0)).isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text(context.tr('nodeNoDividends'), style: _hint)))
          else
            ...nm.dividends.where((d) => double.parse(d.amount) > 0).map((d) => _row(d.symbol, '${d.amount} ${d.symbol}', accent: SinpraTheme.emerald300)),
          if ((nm.referralDividends.where((d) => double.parse(d.amount) > 0)).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(context.tr('nodeReferralDividends'), style: _hint),
            ...nm.referralDividends.where((d) => double.parse(d.amount) > 0).map((d) => _row(d.symbol, '${d.amount} ${d.symbol}', accent: SinpraTheme.amber300)),
          ],
        ]),
      ],
    ];
  }

  // ── Withdraw ─────────────────────────────
  List<Widget> _withdrawTab() {
    final activeAddr = context.read<EmbeddedWalletStore>().activeAddress ?? '';
    final effectiveAddr = _withdrawAddress.isEmpty ? activeAddr : _withdrawAddress;
    final feePercent = _config?.withdrawFeePercent ?? 0;
    final wAmt = double.tryParse(_withdrawAmount) ?? 0;
    final wFee = (wAmt * feePercent) / 100;
    final wNet = (wAmt - wFee).clamp(0, double.infinity);
    final pos = _payouts.where((b) => double.parse(b.amount) > 0).toList();
    return [
      if (pos.isNotEmpty) ...[
        _darkCard([
          Text(context.tr('withdrawTitle'), style: _h2),
          const SizedBox(height: 10),
          ...pos.map((b) {
            final key = '${b.business}:${b.slot}';
            final form = _payoutForm[key] ?? _PayoutForm(address: effectiveAddr);
            final label = b.business == 'node_holder'
                ? context.tr('withdrawNodeHolder')
                : b.business == 'node_referrer'
                    ? context.tr('withdrawNodeReferrer')
                    : context.tr('withdrawContractAdmin');
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(label, style: const TextStyle(color: SinpraTheme.slate300, fontSize: 13)),
                  Text('${b.amount} ${b.symbol}', style: const TextStyle(color: SinpraTheme.emerald300, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _darkInput(context.tr('withdrawEnterAmount')),
                      onChanged: (v) => setState(() => _payoutForm[key] = _PayoutForm(amount: v, address: form.address)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => _payoutForm[key] = _PayoutForm(amount: b.amount, address: form.address)),
                    child: Text(context.tr('bizUseMax')),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: _darkInput(context.tr('withdrawEnterAddress'), mono: true),
                  controller: TextEditingController(text: form.address),
                  onChanged: (v) => setState(() => _payoutForm[key] = _PayoutForm(amount: form.amount, address: v)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _handlePayoutWithdraw(b.business, b.slot, b.amount),
                    child: Text(context.tr('withdrawApply')),
                  ),
                ),
              ]),
            );
          }),
        ]),
        const SizedBox(height: 12),
      ],
      _darkCard([
        Text(context.tr('withdrawContractRelease'), style: _h2),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('bizWithdrawable'), style: _hint),
            const SizedBox(height: 4),
            Text('${_overview?.withdrawable ?? '0'} $_sym', style: const TextStyle(color: SinpraTheme.emerald300, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(context.tr('withdrawAmount'), style: const TextStyle(color: SinpraTheme.slate300, fontSize: 13)),
          TextButton(
            onPressed: () => setState(() => _withdrawAmount = _overview?.withdrawable ?? '0'),
            child: Text(context.tr('bizUseMax')),
          ),
        ]),
        TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: _darkInput('0.00'),
          controller: TextEditingController(text: _withdrawAmount),
          onChanged: (v) => setState(() => _withdrawAmount = v),
        ),
        const SizedBox(height: 12),
        Text(context.tr('withdrawAddress'), style: const TextStyle(color: SinpraTheme.slate300, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _darkInput('', mono: true),
          controller: TextEditingController(text: effectiveAddr),
          onChanged: (v) => setState(() => _withdrawAddress = v),
        ),
        const SizedBox(height: 12),
        _row('${context.tr('bizFeeLabel')} ($feePercent%)', '${formatAmount(wFee)} $_sym'),
        _row(context.tr('withdrawYouReceive'), '${formatAmount(wNet)} $_sym', accent: SinpraTheme.emerald400),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _handleWithdraw,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(context.tr('withdrawSubmitBtn')),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _darkCard([
        Text(context.tr('withdrawHistory'), style: _h2),
        const SizedBox(height: 8),
        if (_overview == null || _overview!.withdrawals.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text(context.tr('withdrawNoHistory'), style: _hint)))
        else
          ..._overview!.withdrawals.map((w) => Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${w.amount} $_sym', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    _wStatus(w.status),
                  ]),
                  const SizedBox(height: 4),
                  Text('${context.tr('withdrawYouReceive')} ${w.net} · ${context.tr('bizFeeLabel')} ${w.fee}',
                      style: _hint),
                  Text(_fmtDate(w.createdAt), style: _hint),
                  if (w.note != null) Text(w.note!, style: const TextStyle(color: SinpraTheme.red300, fontSize: 11)),
                ]),
              )),
      ]),
    ];
  }

  Widget _wStatus(String s) {
    final label = s == 'paid'
        ? context.tr('wPaid')
        : s == 'rejected'
            ? context.tr('wRejected')
            : context.tr('wPending');
    final color = s == 'paid'
        ? SinpraTheme.emerald300
        : s == 'rejected'
            ? SinpraTheme.red300
            : SinpraTheme.amber300;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }

  // ── helpers ─────────────────────────────
  Widget _darkCard(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _miniStat(String label, String value, {Color accent = Colors.white}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: SinpraTheme.slate400, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {Color accent = Colors.white}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: SinpraTheme.slate400, fontSize: 13)),
          Text(value, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  InputDecoration _darkInput(String hint, {bool mono = false}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: SinpraTheme.slate400, fontSize: 13),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white24)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SinpraTheme.brand500)),
      );

  String _fmtDate(DateTime t) => '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _toastView() => Positioned(
        bottom: 24,
        left: 24,
        right: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: SinpraTheme.slate900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SinpraTheme.emerald500.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle, color: SinpraTheme.emerald400, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_toast!, style: const TextStyle(color: Colors.white, fontSize: 13))),
          ]),
        ),
      );
}

class _PayoutForm {
  String amount;
  String address;
  _PayoutForm({this.amount = '', this.address = ''});
}

const _h2 = TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold);
const _hint = TextStyle(color: SinpraTheme.slate400, fontSize: 12);
