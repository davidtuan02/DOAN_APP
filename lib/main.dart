import 'package:flutter/material.dart';
import 'screens/board_screen.dart' as board;
import 'screens/backlog_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/account_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/projects_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/project.dart';
import 'config/api_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jira Clone App',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0052CC),
          primaryContainer: const Color(0xFF4C9AFF),
          secondary: const Color(0xFF0052CC),
          secondaryContainer: const Color(0xFF4C9AFF),
          surface: Colors.white,
          background: const Color(0xFFF4F5F7),
          error: Colors.red.shade700,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0052CC),
          foregroundColor: Colors.white,
          elevation: 4.0,
        ),
        cardTheme: CardThemeData(
          elevation: 1.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF0052CC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          ),
        ),
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
  Project? _selectedProject;

  late final List<Widget> _rootScreens;

  @override
  void initState() {
    super.initState();
    _rootScreens = [
      ProjectsScreen(
        userId: widget.userId, 
        accessToken: widget.accessToken,
        onProjectSelected: _handleProjectSelected,
        initialProject: _selectedProject,
      ),
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

  void _handleProjectSelected(Project project) {
    setState(() {
      _selectedProject = project;
      // Cập nhật lại ProjectsScreen với project mới
      _rootScreens[0] = ProjectsScreen(
        userId: widget.userId,
        accessToken: widget.accessToken,
        onProjectSelected: _handleProjectSelected,
        initialProject: project,
      );
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/count'),
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
    if (index == 3) {
      _fetchUnreadCount();
    }
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return ProjectsScreen(
          userId: widget.userId,
          accessToken: widget.accessToken,
          onProjectSelected: _handleProjectSelected,
          initialProject: _selectedProject,
        );
      case 1:
        if (_selectedProject != null) {
          return board.BoardScreen(
            project: _selectedProject!,
            accessToken: widget.accessToken,
          );
        } else {
          return const Center(child: Text('Please select a project from the Projects tab.'));
        }
      case 2:
        if (_selectedProject != null) {
          return BacklogScreen(
            userId: widget.userId,
            accessToken: widget.accessToken,
            projectId: _selectedProject!.id!,
            projectName: _selectedProject!.name ?? 'Unnamed Project',
          );
        } else {
          return const Center(child: Text('Please select a project from the Projects tab.'));
        }
      case 3:
        return _rootScreens[1];
      case 4:
        return _rootScreens[2];
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.folder_open),
            label: 'Projects',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Board',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Backlog',
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
            label: 'Account',
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
