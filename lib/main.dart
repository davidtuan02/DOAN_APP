import 'package:flutter/material.dart';
import 'screens/projects_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/account_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            final userId = args['userId'] as String?;
            final accessToken = args['accessToken'] as String?;

            if (userId != null && accessToken != null) {
              return MainScreen(userId: userId, accessToken: accessToken);
            } else {
              print('Invalid arguments received for /main route: userId=$userId, accessToken=$accessToken');
              Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
              return const SizedBox();
            }
          } else {
            print('No arguments received for /main route or unexpected type: $args');
            Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
            return const SizedBox();
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
  int _unreadCount = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ProjectsScreen(userId: widget.userId, accessToken: widget.accessToken),
      const IssuesScreen(),
      NotificationsScreen(
        accessToken: widget.accessToken,
        onUnreadCountChanged: (count) {
          setState(() {
            _unreadCount = count;
          });
        },
      ),
      AccountScreen(
        accessToken: widget.accessToken,
      ),
    ];
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/notifications/count'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final countData = json.decode(response.body);
        setState(() {
          _unreadCount = countData['count'] ?? 0;
        });
      } else {
        print('Failed to load unread count: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
      _fetchUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Projects',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bug_report),
            label: 'Issues',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
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
