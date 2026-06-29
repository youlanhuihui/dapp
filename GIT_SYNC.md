# SINPRA App Git 同步说明

## 本仓库状态

- 分支：`main`
- 基线版本：`0.2.2+5`（含钱包导入修复）
- 远程：`https://github.com/youlanhuihui/dapp.git`

## 首次推送到 GitHub（本机）

1. 登录 GitHub CLI（浏览器授权，**不要用账号密码写入命令行**）：

   ```powershell
   gh auth login
   ```

   选择：GitHub.com → HTTPS → Login with a web browser

2. 创建远程仓库并推送：

   ```powershell
   cd D:\dapp\sinpra-app\sinpra-app
   gh repo create dapp --private --source=. --remote=origin --push
   ```

   若仓库已在网页上创建，则：

   ```powershell
   git remote add origin https://github.com/youlanhuihui/dapp.git
   git push -u origin main
   ```

   推送时用户名填 `youlanhuihui`，密码处填 **GitHub Personal Access Token**（不是登录密码）。

## 另一台电脑拉取代码

```powershell
git clone https://github.com/youlanhuihui/dapp.git
cd sinpra-app
flutter pub get
```

复制签名文件（**不要提交到 Git**）：

- `android/key.properties`
- `android/sinpra-release.jks`
- `android/local.properties`（或按 `local.properties.example` 配置）

## 日常协作

```powershell
git pull
# ... 修改代码 ...
git add .
git commit -m "说明"
git push
```

## 不会进 Git 的文件（已在 .gitignore）

- `build/`、`111/`~`444/` 历史快照
- `android/key.properties`、`*.jks`、`local.properties`
- `*.apk`
