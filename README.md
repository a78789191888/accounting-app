# 轻记账

一个本地优先的 Flutter 记账 App，适合在 iPhone 上记录日常收支。

## 功能

- 收入和支出记录
- 金额、分类、日期、备注
- 月度收入、支出、结余统计
- 月度预算和预算使用进度
- 分类支出统计
- 按分类或备注搜索
- 按收入/支出筛选
- CSV 导入和导出
- 数据保存在手机本地，不上传云端

## 重要说明

本项目可以通过 Codemagic 或 GitHub Actions 在 macOS 云端构建 `Runner-unsigned.ipa`，但它是未签名 IPA。

没有 Apple Developer 账号、证书和描述文件时，iPhone 不能直接安装这个 IPA。要安装到真机，需要后续使用以下任一方式签名：

- 付费 Apple Developer 账号：适合 TestFlight 或 App Store。
- 普通 Apple ID：适合短期侧载，通常 7 天需要重新签名。
- 第三方签名服务：请自行评估安全性和稳定性。

## 本地开发

需要先安装 Flutter SDK。

```powershell
flutter pub get
flutter test
flutter run
```

## 使用 Codemagic 构建未签名 IPA

1. 打开 `https://codemagic.io/` 并登录。
2. 点击 `Add application`。
3. 选择 GitHub，然后选择本仓库 `accounting-app`。
4. 选择 `codemagic.yaml` 作为构建配置。
5. 选择 workflow：`Build unsigned iOS IPA`。
6. 点击 `Start new build`。
7. 构建完成后，在 Artifacts 中下载 `Runner-unsigned.ipa`。

Codemagic 配置文件位于 `codemagic.yaml`。

## 使用 GitHub Actions 构建未签名 IPA

1. 把本项目推送到 GitHub 仓库。
2. 打开仓库的 `Actions` 页面。
3. 选择 `Build unsigned iOS IPA`。
4. 点击 `Run workflow`。
5. 构建完成后，在 Artifacts 中下载 `Runner-unsigned-ipa`。

workflow 文件位于 `.github/workflows/ios-unsigned-ipa.yml`。

## CSV 格式

导入 CSV 时支持以下表头：

```csv
日期,类型,分类,金额,备注
2026-06-02,支出,餐饮,28.50,午餐
2026-06-02,收入,工资,8000.00,六月工资
```

日期格式使用 `YYYY-MM-DD`，类型使用 `收入` 或 `支出`。
