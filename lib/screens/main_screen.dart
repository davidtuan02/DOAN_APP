import 'package:app/screens/account_screen.dart';
import 'package:app/screens/issues_screen.dart';
import 'package:flutter/material.dart';
import 'projects_screen.dart';
import 'notifications_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'backlog_screen.dart';
import 'board_screen.dart' as board;
import '../models/project.dart';
import '../config/api_config.dart';

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
  int _unreadCount = 0;
  List<Widget> _screens = [];
  Project? _selectedProject;

  @override
  void initState() {
    super.initState();
    _screens = [
      ProjectsScreen(
        userId: widget.userId,
        accessToken: widget.accessToken,
        onProjectSelected: _handleProjectSelected,
      ),
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
    _fetchNotificationCount();
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/count'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

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

  void _handleProjectSelected(Project project) {
    setState(() {
      _selectedProject = project;
    });
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
        return _screens[2];
      case 4:
        return _screens[3];
      default:
        return const SizedBox();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) { // Notifications tab
      _fetchNotificationCount();
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
        onTap: _onItemTapped,
      ),
    );
  }
} 