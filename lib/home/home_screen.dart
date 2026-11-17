import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final String? userName;

  const HomeScreen({super.key, this.userName});

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(userName: userName);
  }
}
