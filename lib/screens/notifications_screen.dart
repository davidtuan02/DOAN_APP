import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/notification.dart';

class NotificationsScreen extends StatefulWidget {
  final String accessToken;

  const NotificationsScreen({Key? key, required this.accessToken}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<UserNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _fetchUnreadCount();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> notificationsJson = json.decode(response.body);
        setState(() {
          _notifications = notificationsJson
              .map((json) => UserNotification.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        print('Failed to load notifications: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _isLoading = false;
        });
        // TODO: Show error message
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        _isLoading = false;
      });
      // TODO: Show error message
    }
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

      if (response.statusCode == 200) {
        final countData = json.decode(response.body);
        setState(() {
          _unreadCount = countData['count'] ?? 0;
        });
      } else {
        print('Failed to load unread count: ${response.statusCode}');
        print('Response body: ${response.body}');
        // TODO: Show error message
      }
    } catch (e) {
      print('Error fetching unread count: $e');
      // TODO: Show error message
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/notifications/$id/read'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (response.statusCode == 200) {
        _fetchNotifications();
        _fetchUnreadCount();
      } else {
        print('Failed to mark as read: ${response.statusCode}');
        print('Response body: ${response.body}');
        // TODO: Show error message
      }
    } catch (e) {
      print('Error marking as read: $e');
      // TODO: Show error message
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/notifications/read-all'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (response.statusCode == 200) {
        _fetchNotifications();
        _fetchUnreadCount();
      } else {
        print('Failed to mark all as read: ${response.statusCode}');
        print('Response body: ${response.body}');
        // TODO: Show error message
      }
    } catch (e) {
      print('Error marking all as read: $e');
      // TODO: Show error message
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:8000/api/notifications/$id'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (response.statusCode == 200) {
        _fetchNotifications();
        _fetchUnreadCount();
      } else {
        print('Failed to delete notification: ${response.statusCode}');
        print('Response body: ${response.body}');
        // TODO: Show error message
      }
    } catch (e) {
      print('Error deleting notification: $e');
      // TODO: Show error message
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return ListTile(
                      title: Text(notification.title),
                      subtitle: Text(
                        '${notification.message}\n${notification.formattedCreatedAt}',
                      ),
                      isThreeLine: true,
                      tileColor: notification.isRead ? null : Colors.blue.shade50,
                      onTap: () {
                        if (!notification.isRead) {
                          _markAsRead(notification.id);
                        }
                        // TODO: Navigate based on notification.link
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteNotification(notification.id);
                        },
                      ),
                    );
                  },
                ),
    );
  }
} 