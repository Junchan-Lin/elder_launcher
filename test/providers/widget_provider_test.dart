import 'dart:typed_data';
import 'package:elder_launcher/constants/channels.dart';
import 'package:elder_launcher/constants/keys.dart';
import 'package:elder_launcher/data_sources/widget_repository.dart';
import 'package:elder_launcher/providers/widget_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';

void main() {
  const widgetsChannel = MethodChannel(channelWidgets);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, null);
  });

  test('addWidget 新增成功時將 widget 加入 favWidgets', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async {
      if (call.method == 'pickAndBindWidget') {
        return {
          'appWidgetId': 42,
          'label': 'Clock',
          'icon': Uint8List.fromList([1, 2, 3]),
          'minHeight': 120,
        };
      }
      return null;
    });

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);
    await provider.addWidget();

    expect(provider.favWidgets.length, 1);
    expect(provider.favWidgets[0].id, '42');
    expect(provider.favWidgets[0].name, 'Clock');
    expect(provider.getWidgetHeight('42'), 120);
  });

  test('addWidget 使用者取消時不新增任何項目', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async => null);

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);
    await provider.addWidget();

    expect(provider.favWidgets, isEmpty);
  });

  test('saveFavWidgets 移除項目時呼叫原生 deleteWidget 並清除快取資料', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.$keyFavWidgets': ['1', '2'],
      'flutter.${keyWidgetLabelPrefix}1': 'Clock',
      'flutter.${keyWidgetLabelPrefix}2': 'Weather',
    });
    await SharedPrefs.init();

    final deletedIds = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async {
      if (call.method == 'deleteWidget') {
        deletedIds.add(call.arguments['appWidgetId'] as int);
      }
      return null;
    });

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);
    await provider.saveFavWidgets(['1']);

    expect(deletedIds, [2]);
    expect(provider.favWidgets.map((e) => e.id), ['1']);
    expect(SharedPrefs.getString('${keyWidgetLabelPrefix}2'), isNull);
  });

  test('載入時偵測到來源 App 已移除的 widget，自動清除該項目', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.$keyFavWidgets': ['1', '2'],
      'flutter.${keyWidgetLabelPrefix}1': 'Clock',
      'flutter.${keyWidgetLabelPrefix}2': 'Uninstalled Widget',
    });
    await SharedPrefs.init();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async {
      if (call.method == 'filterValidWidgetIds') {
        return [1];
      }
      return null;
    });

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);

    expect(provider.favWidgets.map((e) => e.id), ['1']);
    expect(SharedPrefs.getList(keyFavWidgets), ['1']);
    expect(SharedPrefs.getString('${keyWidgetLabelPrefix}2'), isNull);
  });
}
