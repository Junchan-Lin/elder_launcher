import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';

class DateTimeProvider extends ChangeNotifier {
  late final Timer _timer;
  final FlutterTts _tts = FlutterTts();
  String _date = '';
  String _time = '';
  String _lunarDate = '';
  String _speakDateText = '';

  DateTimeProvider() {
    _tts.setLanguage('zh-TW');
    _timer = Timer.periodic(
        const Duration(seconds: 1), (timer) => _updateDateTime());
  }

  String get date => _date;
  String get time => _time;
  String get lunarDate => _lunarDate;

  Future<void> speakDate() async {
    await _tts.speak(_speakDateText);
  }

  @override
  void dispose() {
    _timer.cancel();
    _tts.stop();
    super.dispose();
  }

  void _updateDateTime() {
    final now = DateTime.now();
    _time = DateFormat.jm().format(now);
    _date = DateFormat.MMMMEEEEd().format(now);
    final lunar = Lunar.fromDate(now);
    _lunarDate =
        '農曆${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    _speakDateText =
        '${now.year}年${now.month}月${now.day}日，$_lunarDate';
    notifyListeners();
  }
}
