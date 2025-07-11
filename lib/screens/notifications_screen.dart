import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/notification.dart' as notif_model;
import '../config/api_config.dart';
import 'dart:async';

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
  String? _error;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Start the timer to fetch notifications every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchNotifications();
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _timer.cancel();
    super.dispose();
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
              const Text('Unread'),
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
            icon: const Icon(Icons.done_all),
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
                      ? 'No unread announcement yet'
                      : 'No announcement yet'),
                )
              : ListView.builder(
                  itemCount: displayedNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = displayedNotifications[index];
                    return Card(
                      elevation: 1.0,
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        leading: Icon(
                          Icons.circle,
                          color: notification.isRead ? Colors.grey.shade400 : Theme.of(context).primaryColor,
                        ),
                        title: Text(
                          notification.title ?? 'No Title',
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            color: notification.isRead ? Colors.grey[700] : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.message ?? 'No message',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.formattedCreatedAt ?? '',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        tileColor: notification.isRead ? null : Theme.of(context).primaryColor.withOpacity(0.05),
                        onTap: () {
                          if (!notification.isRead) {
                            _markAsRead(notification.id);
                          }
                          // TODO: Navigate based on notification.link
                        },
                        // TODO: Add trailing icon for deletion if needed
                      ),
                    );
                  },
                ),
    );
  }
} 