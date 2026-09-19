// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'config/app_config.dart';
import 'features/login/view/login_page.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Resolved once, at the composition root. A malformed BACKEND_BASE_URL
  // throws here, at startup, rather than at first use.
  final config = AppConfig.fromEnv();

  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(FinanceA2UiApp(config: config));
}

class FinanceA2UiApp extends StatefulWidget {
  const FinanceA2UiApp({required this.config, super.key});

  final AppConfig config;

  @override
  State<FinanceA2UiApp> createState() => _FinanceA2UiAppState();
}

class _FinanceA2UiAppState extends State<FinanceA2UiApp> {
  // Built from const tokens, so they never vary: building them per rebuild
  // would re-run ColorScheme.fromSeed on every theme toggle.
  static final ThemeData _lightTheme = AppTheme.light();
  static final ThemeData _darkTheme = AppTheme.dark();

  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinanceA2Ui',
      themeMode: _themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      home: LoginPage(config: widget.config, onToggleTheme: _toggleTheme),
    );
  }
}
