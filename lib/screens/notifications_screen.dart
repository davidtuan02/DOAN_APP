import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/notification.dart' as notif_model;
import '../config/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  final String accessToken;
  final Function(int) onUnreadCountChanged;

  const NotificationsScreen({
    Key? key,
    required this.accessToken,
    required this.onUnreadCountChanged,
  }) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<notif_model.UserNotification> _notifications = [];
  bool _isLoading = false;
  bool _showUnreadOnly = false; // State variable for filtering

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _notifications = data.map((json) => notif_model.UserNotification.fromJson(json)).toList();
          _isLoading = false;
        });
        _updateUnreadCount(); // Update unread count after fetching
      } else {
        print('Failed to load notifications: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          final index = _notifications.indexWhere((notif) => notif.id == notificationId);
          if (index != -1) {
            _notifications[index].isRead = true;
          }
        });
        _updateUnreadCount(); // Update unread count after marking as read
      } else {
        print('Failed to mark as read: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error marking as read: $e');
      if (!mounted) return;
    }
  }

   Future<void> _markAllAsRead() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 204) {
        setState(() {
          for (var notif in _notifications) {
            notif.isRead = true;
          }
          _isLoading = false;
        });
        _fetchNotifications(); // Reload notifications after marking all as read
      } else {
        print('Failed to mark all as read: ${response.statusCode}');
        print('Response body: ${response.body}');
         setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error marking all as read: $e');
      if (!mounted) return;
       setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateUnreadCount() {
    final unreadCount = _notifications.where((notif) => !notif.isRead).length;
    widget.onUnreadCountChanged(unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    // Apply filter to the notifications list
    final displayedNotifications = _showUnreadOnly
        ? _notifications.where((notification) => !notification.isRead).toList()
        : _notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
         actions: [
          // Filter toggle
          Row(
            children: [
              const Text('Chưa đọc'),
              Switch(
                value: _showUnreadOnly,
                onChanged: (value) {
                  setState(() {
                    _showUnreadOnly = value;
                  });
                },
              ),
            ],
          ),
          // Mark all as read button
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : displayedNotifications.isEmpty
              ? Center(
                  child: Text(_showUnreadOnly
                      ? 'Không có thông báo chưa đọc'
                      : 'Không có thông báo nào'),
                )
              : ListView.builder(
                  itemCount: displayedNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = displayedNotifications[index];
                    return ListTile(
                      title: Text(notification.title ?? ''),
                      subtitle: Text(
                        '${notification.message ?? ''}\n${notification.formattedCreatedAt}',
                      ),
                      isThreeLine: true,
                      tileColor: notification.isRead ? null : Colors.blue.shade50,
                      onTap: () {
                        if (!notification.isRead) {
                          _markAsRead(notification.id);
                        }
                        // TODO: Navigate based on notification.link
                      },
                      // TODO: Add trailing icon for deletion if needed
                    );
                  },
                ),
    );
  }
} 