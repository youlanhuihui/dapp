# SINPRA APP 打包说明

新工程目录：`/www/wwwroot/dapp/sinpra-app`（Flutter 包名 `sinpra_app`）。
本工程仅复用既有 IM 机制层（`lib/core`、`lib/shared`、`lib/core/wallet`），UI 全部原生重写并对齐 Web。
**客户端版本不挂载** 任务 / 设备 / AI 模式路由；文案以 Web 为准，不含「AI / 设备 / 数字大脑」。

> 工程已内置 `android/` 脚手架（含 gradle wrapper、`build.gradle.kts`、`AndroidManifest.xml`、`MainActivity.kt`、图标与启动样式），applicationId = `com.sinpra.sinpra_app`，应用名 = `SINPRA`。
> **你只需把整个 `sinpra-app` 文件夹复制到本地电脑，做完「1. 本机配置」即可直接打包，无需再跑 `flutter create`。**

## 0. 环境准备

- Flutter SDK ≥ 3.2（建议 3.24 或更新稳定版）
- Android Studio + Android SDK（compileSdk 34 / build-tools 34.x）
- JDK 17（AGP 8 推荐）
- 一台可联网的打包机（首次需拉取 pub 依赖）

校验：
```bash
flutter --version          # 需 ≥ 3.2
flutter doctor -v
```

## 1. 本机配置（复制到本地后必做）

1. 拉取依赖：
   ```bash
   cd sinpra-app
   flutter pub get
   ```
2. 创建本机 `android/local.properties`（仓库里给了 `local.properties.example`，复制改名后改路径）：
   ```properties
   flutter.sdk=/你的/Flutter/SDK/路径
   sdk.dir=/你的/Android/Sdk/路径
   ```
   > `settings.gradle.kts` 启动时会读取 `local.properties` 里的 `flutter.sdk`，缺失会构建失败。
3.（可选）正式签名：把 `android/key.properties.example` 复制为 `android/key.properties` 并填入你的 keystore 信息；再把自己的 `.jks` 放到对应路径。
   - 未提供 `key.properties` 时，release 会自动回落到 debug 签名（可出包，但不能上架）。
   - 生成 keystore：
     ```bash
     keytool -genkey -v -keystore sinpra-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sinpra
     ```

## 2. 配置应用信息

### 2.1 应用名 / 图标
- 应用名：`android/app/src/main/AndroidManifest.xml` 中 `android:label="SINPRA"`（已设好，按需改）。
- 图标与启动图：当前用的是占位 `ic_launcher.png`；如需替换，把素材放入 `assets/icon/`，用 `flutter_launcher_icons` / `flutter_native_splash`（在 `pubspec.yaml` 追加 dev_dependencies 并配置）。

### 2.2 网络权限
`lib/core/config/app_config.dart` 已配置 API/WS/RPC 地址。若后端为 **http（非 https）**，需要在 `AndroidManifest.xml` 加：
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<!-- 仅调试用 cleartext，生产请走 https -->
<application android:usesCleartextTraffic="true" ...>
```
并把 `network_security_config` 指向允许的明文域名（推荐生产强制 https，则无需此项）。

### 2.3 minSdk
`solana` / `web_socket_channel` 等需 minSdk ≥ 21。确认 `android/app/build.gradle.kts`：
```kotlin
android {
    defaultConfig {
        minSdk = 21
        targetSdk = 34
        compileSdk = 34
        applicationId = "com.sinpra.sinpra_app"
        versionCode = 1
        versionName = "0.1.0"
    }
}
```

## 3. 切换网络（devnet / mainnet）

`lib/core/config/app_config.dart`：
- 开发联调：`solanaNetwork = 'devnet'`，`apiBaseUrl` / `wsUrl` 指向测试环境。
  - 也可不改代码，用 `--dart-define` 覆盖：`flutter build apk --release --dart-define=SOLANA_NETWORK=devnet --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 --dart-define=WS_URL=ws://10.0.2.2:8000/ws/client`
- 正式发布：`solanaNetwork = 'mainnet-beta'`，`apiBaseUrl` / `wsUrl` 指向生产域名（https，默认 `https://api.sinpra.co/api/v1`，按你实际域名改）。

> 业务页质押 / 节点购买为**真实上链**，正式包务必切到 mainnet 并复核金库地址。

## 4. 打包

### 4.1 调试 APK
```bash
flutter run                  # 连真机/模拟器直跑
flutter build apk --debug    # 产出 build/app/outputs/flutter-apk/app-debug.apk
```

### 4.2 正式 Release APK
```bash
flutter build apk --release --target-platform android-arm64,android-arm,android-x64
```
产物：`build/app/outputs/flutter-apk/app-release.apk`

### 4.3 分架构包（体积更小）
```bash
flutter build apk --split-per-abi --release
# 产出 app-arm64-v8a-release.apk / app-armeabi-v7a-release.apk / app-x86_64-release.apk
```

### 4.4 上架用 AAB（Google Play）
```bash
flutter build appbundle --release
# 产物 build/app/outputs/bundle/release/app-release.aab
```

## 5. 安装验证

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
首次进入请：注册/登录 → 我的 → 创建内置钱包 → 备份助记词 → 业务页参与质押 / 购买节点。

## 6. 常见问题

- **构建报 `flutter.sdk not set in local.properties`**：未创建/填写 `android/local.properties`，按第 1 步配置。
- **钱包创建失败 / 余额读不到**：检查 `preferredRpc` 是否可达，devnet 可用 `https://api.devnet.solana.com`。
- **登录 401**：检查 `apiBaseUrl` 与后端 `/api/v1` 前缀是否一致；token 已实现自动刷新与 401 重登录。
- **明文 http 被拦**：见 2.2 配置 `usesCleartextTraffic` 或切 https。
- **签名报错**：确认 `key.properties` 路径与 `signingConfigs` 引用一致，keystore 别名匹配。
- **release 拿到的是 debug 签名包**：未提供 `key.properties`，回落了 debug 签名；上架前需配置正式签名。

## 7. 目录约定

```
sinpra-app/
├── android/           # 已内置脚手架（gradle wrapper / build.gradle.kts / Manifest / MainActivity / 图标）
├── lib/
│   ├── app/           # 主题、路由、根 Widget
│   ├── core/          # 复用：api/auth/i18n/wallet/ws/config/brand/ui
│   ├── shared/        # 复用：models / services / utils
│   └── modules/       # 原生 UI：auth/chat/contacts/business/settings/wallet
├── pubspec.yaml
├── analysis_options.yaml
└── BUILD.md
```
