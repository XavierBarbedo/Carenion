import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/auth_pages.dart';
import 'pages/home_page.dart';
import 'services/settings_service.dart';
import 'package:intl/date_symbol_data_local.dart';

late final SettingsService settingsService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT', null);
  await initializeDateFormatting('en_US', null);

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final prefs = await SharedPreferences.getInstance();
  settingsService = SettingsService(prefs);

  runApp(const CarenionApp());
}

class CarenionApp extends StatelessWidget {
  const CarenionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Carenion',
          debugShowCheckedModeBanner: false,
          themeMode: settingsService.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.amber, 
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            textTheme: Typography.material2021().white.apply(
              fontFamily: 'Roboto',
            ),
          ),
          home: const LoginPage(),
        );
      },
    );
  }
}
