import 'package:elder_launcher/data_sources/line_repository.dart';
import 'package:elder_launcher/providers/line_provider.dart';
import 'package:elder_launcher/data_sources/app_repository.dart';
import 'package:elder_launcher/data_sources/contact_repository.dart';
import 'package:flutter/material.dart';
import 'utils/shared_prefs.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'generated/l10n.dart';
import 'providers/app_provider.dart';
import 'providers/contact_provider.dart';
import 'ui/pages/home_page/home_page.dart';
import 'ui/router.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>(
            create: (_) => AppProvider(AppRepository())),
        ChangeNotifierProvider<ContactProvider>(
            create: (_) => ContactProvider(ContactRepository())),
        ChangeNotifierProvider<LineProvider>(
            create: (_) => LineProvider(LineRepository())),
      ],
      child: MaterialApp(
        title: 'Elder Launcher',
        home: const DefaultTabController(length: 3, child: HomePage()),
        onGenerateRoute: generateRoute,
        localizationsDelegates: const [
          S.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        theme: tealTheme,
        darkTheme: darkTheme,
      ),
    );
  }
}
