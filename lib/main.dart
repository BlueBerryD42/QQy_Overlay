
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/comic_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ComicProvider(),
      child: MaterialApp(
        title: 'QRganize',
        theme: ThemeData.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
