import 'package:flutter/material.dart';
import 'projects_screen.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';

class MainScreen extends StatefulWidget {
  final String userId;
  final String accessToken;

  const MainScreen({
    Key? key,
    required this.userId,
    required this.accessToken,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ProjectsScreen(
            userId: widget.userId,
            accessToken: widget.accessToken,
          ),
          AccountScreen(
            accessToken: widget.accessToken,
          ),
          NotificationsScreen(
            accessToken: widget.accessToken,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }
} 