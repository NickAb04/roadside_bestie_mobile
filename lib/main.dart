import 'package:flutter/material.dart';
import 'screens/home_screen.dart'; // This connects to your new file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Removes the ugly 'Debug' banner
      title: 'Roadside Bestie',
      theme: ThemeData(
        primarySwatch: Colors.orange, // Matches your mechanics theme
        useMaterial3: true,
      ),
      home: HomeScreen(), // Starts your App here
    );
  }
}