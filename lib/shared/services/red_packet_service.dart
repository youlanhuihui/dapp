import 'package:dio/dio.dart';
import 'package:sinpra_app/core/api/api_client.dart';
import 'package:sinpra_app/core/api/api_endpoints.dart';
import 'package:sinpra_app/core/config/app_config.dart';
import 'package:sinpra_app/core/wallet/embedded_wallet_store.dart';
import 'package:sinpra_app/core/wallet/fund_red_packet.dart';
import 'package:sinpra_app/shared/models/message.dart';
import 'package:sinpra_app/shared/services/chat_service.dart';

/// 聊天发红包：创建托管 → 上链注资 → 发送 red_packet_card 消息（与 Web 一致）。
class RedPacketService {
  final ApiClient _api;
  final EmbeddedWalletStore _wallet;
  late final ChatService _chat;

  RedPacketService({
    required ApiClient api,
    required EmbeddedWalletStore wallet,
  })  : _api = api,
        _wallet = wallet {
    _chat = ChatService(api: _api);
  }

  Future<MessageModel> sendInConversation({
    required String convId,
    required String fromAddress,
    required String? mint,
    required String symbol,
    required int decimals,
    required String totalAmount,
    required int count,
    required String mode,
    required String greeting,
    void Function(String phase)? onProgress,
  }) async {
    if (!_wallet.isUnlocked) throw Exception('钱包已锁定，请先解锁');

    onProgress?.call('create');
    final created = await _createPacket(
      mint: mint,
      symbol: symbol,
      decimals: decimals,
      senderAddress: fromAddress,
      totalAmount: totalAmount,
      count: count,
      mode: mode,
      greeting: greeting,
    );

    onProgress?.call('fund');
    try {
      final fundSig = await fundRedPacket(
        wallet: _wallet,
        fromAddress: fromAddress,
        escrowAddress: created.escrowAddress,
        mint: mint,
        decimals: decimals,
        totalBase: created.totalBase,
        solBuffer: created.solBuffer,
      );

      onProgress?.call('confirm');
      await _api.post(
        ApiEndpoints.redPacketFund(created.id),
        data: {'fund_tx': fundSig},
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
    } catch (e) {
      final friendly = friendlyRedPacketError(e);
      throw Exception(friendly ?? e.toString());
    }

    onProgress?.call('message');
    return _chat.sendRedPacketCard(
      convId,
      packetId: created.id,
      tokenSymbol: symbol,
      totalAmount: totalAmount,
      packetCount: count,
      packetType: mode,
      greeting: greeting,
      network: AppConfig.isDevnet ? 'devnet' : 'mainnet-beta',
    );
  }

  Future<({String id, String escrowAddress, String totalBase, int solBuffer})>
      _createPacket({
    required String? mint,
    required String symbol,
    required int decimals,
    required String senderAddress,
    required String totalAmount,
    required int count,
    required String mode,
    required String greeting,
  }) async {
    final res = await _api.post(
      ApiEndpoints.redPackets,
      data: {
        'mint': mint,
        'symbol': symbol,
        'decimals': decimals,
        'network': AppConfig.isDevnet ? 'devnet' : 'mainnet-beta',
        'sender_address': senderAddress,
        'total_amount': totalAmount,
        'count': count,
        'mode': mode,
        'greeting': greeting,
      },
    );
    final data = res.data as Map<String, dynamic>;
    return (
      id: data['id'] as String,
      escrowAddress: data['escrow_address'] as String,
      totalBase: data['total_base'] as String,
      solBuffer: (data['sol_buffer'] as num).toInt(),
    );
  }
}
