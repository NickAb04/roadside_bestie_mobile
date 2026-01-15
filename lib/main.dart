import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/providers/vehicle_provider.dart';
import 'features/sos/providers/emergency_provider.dart';
import 'features/booking/providers/booking_provider.dart';
import 'features/mechanic/providers/mechanic_provider.dart';
import 'screens/mechanic_dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => MechanicProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Roadside Bestie',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            home: _getHomeWidget(auth),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/home': (context) => const HomeScreen(),
              '/mechanic-dashboard': (context) => MechanicDashboard(),
            },
          );
        },
      ),
    );
  }

  Widget _getHomeWidget(AuthProvider auth) {
    switch (auth.status) {
      case AuthStatus.authenticated:
        if (auth.role == 'mechanic') {
          return MechanicDashboard();
        }
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.unknown:
      default:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}