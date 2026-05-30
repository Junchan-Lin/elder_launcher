# 農曆日期 + TTS 設計文件

**Goal:** 在 AppBar 國曆日期下方加入農曆日期列，列尾有喇叭按鈕可念出今天日期。

**Architecture:** `DateTimeProvider` 統一管理農曆字串與 TTS 生命週期，`home_page.dart` 在現有日期列下方插入農曆列。

**Tech Stack:** Flutter, `lunar ^2.0.0`（農曆換算）, `flutter_tts ^4.0.0`（語音合成 zh-TW）

---

## 版面

AppBar bottom 區域（由上到下）：

```
[ 時間（headerTime 40px）     ]
[ 國曆日期（headerDate 30px）  ]
[ 農曆X月X日（24px）  🔊 icon ]
[ TabBar                      ]
```

農曆列為 `Row(mainAxisAlignment: MainAxisAlignment.center)`，內含農曆文字和 `IconButton(Icons.volume_up)`。

---

## DateTimeProvider 變更

**新增欄位：**
```dart
String _lunarDate = '';
final FlutterTts _tts = FlutterTts();
```

**農曆格式（`_updateDateTime()` 內）：**
```dart
final now = DateTime.now();
final lunar = Lunar.fromDate(now);
_lunarDate = '農曆${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
// TTS 用中文日期（獨立於顯示用的 _date 格式）
_speakDateText =
    '${now.year}年${now.month}月${now.day}日，$_lunarDate';
```

**新增欄位：**
```dart
String _speakDateText = '';
```

**新增 getter：**
```dart
String get lunarDate => _lunarDate;
```

**新增方法：**
```dart
Future<void> speakDate() async {
  await _tts.speak(_speakDateText);
}
```

**TTS 初始化（constructor）：**
```dart
_tts.setLanguage('zh-TW');
```

**dispose() 補充：**
```dart
_tts.stop();
```

---

## home_page.dart 變更

在現有 `AutoSizeText(dateTimeProvider.date, ...)` 之後，`TabBar(...)` 之前插入：

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    AutoSizeText(
      dateTimeProvider.lunarDate,
      group: appBarTextSizeGroup,
      maxLines: 1,
      style: TextStyles.headerLunar,
    ),
    IconButton(
      icon: const Icon(Icons.volume_up),
      onPressed: dateTimeProvider.speakDate,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    ),
  ],
),
```

`Consumer<DateTimeProvider>` 包裹範圍需延伸至含農曆列與喇叭按鈕。

---

## theme.dart 變更

在 `TextStyles` 加入：

```dart
static const headerLunar = TextStyle(fontSize: 24);
```

---

## 不在範圍內

- 農曆節氣、節日顯示
- TTS 語速/音量設定
- 多語系 TTS（固定 zh-TW，目標使用者為台灣家庭）
- 農曆年份顯示
