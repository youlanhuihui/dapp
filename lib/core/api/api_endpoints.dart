class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // APP 版本（公开，无需登录）
  static const String appVersion = '/app/version';

  // Users
  static const String currentUser = '/users/me';
  static String userById(String id) => '/users/$id';
  static const String userWallets = '/users/me/wallets';
  static String userWalletById(String id) => '/users/me/wallets/$id';
  static String userWalletPrimary(String id) =>
      '/users/me/wallets/$id/primary';
  static const String userReferral = '/users/me/referral';
  static const String userReferralDetail = '/users/me/referral/detail';
  static const String userReferralAttribution =
      '/users/me/referral/attribution';
  static const String userWalletSettings = '/users/me/wallet-settings';
  static const String tokensSupported = '/tokens/supported';
  static const String userTokens = '/users/me/tokens';

  // 钱包云端加密备份（与 Web 一致：服务端只存密文）
  static const String embeddedWallet = '/users/me/embedded-wallet';

  // 红包（创建 → 上链注资 → 发聊天卡片）
  static const String redPackets = '/red-packets';
  static String redPacketFund(String packetId) => '/red-packets/$packetId/fund';
  static String redPacketClaim(String packetId) => '/red-packets/$packetId/claim';

  // 生态卡
  static const String ecosystemPresets = '/ecosystem/presets';
  static String conversationEcosystemCards(String convId) =>
      '/conversations/$convId/ecosystem-cards';

  // 会话（POST 需尾斜杠，避免 FastAPI 307 重定向）
  static const String conversations = '/conversations/';
  static String conversationById(String id) => '/conversations/$id';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages';
  static String conversationMembers(String id) =>
      '/conversations/$id/members';
  static String conversationMessagePatch(String convId, String msgId) =>
      '/conversations/$convId/messages/$msgId';

  // 消息
  static const String messages = '/messages';
  static String messageById(String id) => '/messages/$id';

  // 业务：质押
  static const String stakingConfig = '/staking/config';
  static const String stakingOverview = '/staking/overview';
  static const String stakingStakes = '/staking/stakes';
  static const String stakingWithdrawals = '/staking/withdrawals';
  static const String stakingFaucet = '/staking/faucet';
  static const String stakingFaucetAirdropSol = '/staking/faucet/airdrop-sol';
  static const String stakingFaucetClaim = '/staking/faucet/claim';

  // 业务：节点质押
  static const String nodeStakingConfig = '/node-staking/config';
  static const String nodeStakingMe = '/node-staking/me';
  static const String nodeStakingPurchase = '/node-staking/purchase';

  // 业务：分润提现
  static const String payoutBalances = '/payouts/balances';
  static const String payoutWithdrawals = '/payouts/withdrawals';

  // 公开功能开关
  static const String adminFeaturesPublic = '/admin/features/public';

  // 联系人 / 好友
  static const String contacts = '/users/contacts';
  static String contactById(String userId) => '/users/contacts/$userId';
  static const String friendRequests = '/friends/requests';
  static String friendRequestAccept(String id) =>
      '/friends/requests/$id/accept';
  static String friendRequestReject(String id) =>
      '/friends/requests/$id/reject';
  static String friendRequestCancel(String id) =>
      '/friends/requests/$id/cancel';
  static const String friendsScanQr = '/friends/scan-qr';
  static const String userSearchExact = '/users/search/exact';

  // 个人二维码
  static const String userMyQr = '/users/me/qr';
  static const String userMyQrRefresh = '/users/me/qr/refresh';

  // 钱包交易记录（与 Web 一致）
  static const String walletTx = '/users/me/wallet-tx';
}
