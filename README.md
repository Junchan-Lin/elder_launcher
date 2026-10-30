# Elder Launcher（客製化版本）

> 這是 [itsarjunsinh/elder_launcher](https://github.com/itsarjunsinh/elder_launcher) 的客製化 fork，原作者為 Arjunsinh Jadeja，依 [MIT License](LICENSE) 授權。
> 這個版本是為家中長輩使用而修改，**不是原作者發布的 App**；Play Store／F-Droid 上的 Elder Launcher 是原作者的版本。
>
> This is a customized fork of [itsarjunsinh/elder_launcher](https://github.com/itsarjunsinh/elder_launcher) (MIT License, © 2020 Arjunsinh Shridevsinh Jadeja). It is not the official app.

## 這個版本的修改

- 繁體中文介面與文案
- LINE 頁籤：長按編輯、拍照或選圖設定頭像、選擇頭像顏色
- 聯絡人頁籤：長按選擇頭像顏色
- 小工具（App Widget）頁籤：新增、移除、排序桌面小工具
- 鎖定時隱藏空白的新增提示；鎖定且沒有資料的頁籤自動隱藏
- 以 Android SDK 36 建置；applicationId 改為 `com.code_sky.customlancher`，可與原作者的 App 同時安裝
- 設計與實作紀錄放在 `docs/superpowers/`

### 自行建置

```bash
flutter pub get
flutter build apk --debug
```

release 版需要自己的簽章金鑰：在 `android/key.properties` 填入 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`（這個檔案不會進 git）。

---

以下為原專案說明：

# Elder Launcher

Elder Launcher is a launcher designed for seniors focused on simplicity and legibility.

Elder Launcher supports pinning favorite apps and contacts to the homescreen for quick access.

<span>
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" height="350" alt="Homescreen with favourite apps">
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" height="350" alt="Homescreen with favourite contacts">
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3.png" height="350" alt="App Drawer">
</span>

## Install（原作者的版本）

<a href="https://play.google.com/store/apps/details?id=xyz.arjunsinh.elderlauncher"><img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="70"></a> <a href="https://apt.izzysoft.de/fdroid/index/apk/xyz.arjunsinh.elderlauncher"><img src="https://gitlab.com/IzzyOnDroid/repo/-/raw/master/assets/IzzyOnDroid.png" height="70"></a>

Also available from [GitHub Releases](https://github.com/itsarjunsinh/elder_launcher/releases)

## Tech

Elder Launcher is developed using [Flutter](flutter.dev).

The app relies heavily on the following open source Flutter packages:

* [contact_service](https://pub.dev/packages/contacts_service) - For accessing contacts
* [device_apps](https://pub.dev/packages/device_apps) - For accessing apps

> Install __Flutter Intl plugin__ ([VS Code](https://marketplace.visualstudio.com/items?itemName=localizely.flutter-intl), [InteliJ](https://plugins.jetbrains.com/plugin/13666-flutter-intl)) for generating localisation files. Your IDE might show errors and warnings if this is not installed.

## More Screenshots
<span>
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/4.png" height="350" alt="Homescreen call shortcut dialog">
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/5.png" height="350" alt="Favourite App selection screen">
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/6.png" height="350" alt="Favourite Contacts reorder screen">
</span>
<br/>

### Dark mode (Android 10+)
Can be enabled from system settings

<span>
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/7.png" height="350" alt="Dark Mode: Homescreen with favourite apps">
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/8.png" height="350" alt="Dark Mode: Homescreen with favourite contacts">
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/9.png" height="350" alt="Dark Mode: App Drawer">
</span>

## License

This project is licensed under the [MIT License](LICENSE). 
