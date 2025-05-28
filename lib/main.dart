import 'package:flutter/material.dart';
import 'screens/projects_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jira Clone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args != null && args is Map<String, dynamic>) {
            return MainScreen(
              userId: args['userId'] as String,
              accessToken: args['accessToken'] as String,
            );
          } else {
            // If arguments are missing or invalid, redirect to login
            // This is a simple way to handle this; more complex apps might show an error or a loading screen
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
            return const Scaffold(body: Center(child: CircularProgressIndicator())); // Or some other placeholder widget
          }
        },
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final String userId;
  final String accessToken;

  const MainScreen({Key? key, required this.userId, required this.accessToken}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ProjectsScreen(userId: widget.userId, accessToken: widget.accessToken),
      const IssuesScreen(),
      const NotificationsScreen(),
      const AccountsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bug_report),
            label: 'Issues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Accounts',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
