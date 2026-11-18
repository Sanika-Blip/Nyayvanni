import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_provider.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (auth.isLoggedIn) {
      // A temporary password must be replaced before anything else.
      if (auth.user!.mustChangePassword) {
        return const ProfileScreen(forcePasswordChange: true);
      }
      return const DashboardScreen();
    }
    return const LoginScreen();
  }
}
