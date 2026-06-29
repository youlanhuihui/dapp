# SINPRA App

SINPRA DApp 移动客户端（Flutter，包名 `sinpra_app`）。

- 仅复用既有 IM 机制层（`lib/core`、`lib/shared`、`lib/core/wallet`），UI 全部原生重写并对齐 Web。
- 4 Tab：聊天 / 联系人 / 业务 / 我的；**不挂载** 任务 / 设备 / AI 模式。
- 内置 Solana 钱包：PIN 加密 + 云端备份，与 Web 一致。
- 业务页原生 5 Tab：收益总览 / 质押参与 / 收益模拟器 / 节点质押 / 提现，质押与节点购买真实上链。
- 文案以 Web 为准，不含「AI / 设备 / 数字大脑」。

## 打包
见 `BUILD.md`。复制到本地后：`flutter pub get` → 配置 `android/local.properties`（按 `local.properties.example`）→ `flutter build apk --release`。

## 目录
```
lib/
  app/      主题、路由、根 Widget
  core/     复用：api / auth / i18n / wallet / ws / config / brand / ui
  shared/   复用：models / services / utils
  modules/  原生 UI：auth / chat / contacts / business / settings / wallet
android/    已内置脚手架
```
