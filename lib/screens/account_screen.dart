import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';
import '../config/api_config.dart';
import '../globale.dart' as globals;

class AccountScreen extends StatefulWidget {
  final String accessToken;

  const AccountScreen({
    Key? key,
    required this.accessToken,
  }) : super(key: key);

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  User? user;
  bool isLoading = false;
  bool isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  final _roleController = TextEditingController();
  String _email = '';
  String _username = '';
  int _age = 0;
  UserRole _role = UserRole.MEMBER;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Profile data: $data'); // Debug print
        setState(() {
          _email = data['email'] ?? '';
          _username = data['username'] ?? '';
          _age = data['age'] ?? 0;
          final roleStr = data['role'] as String?;
          _role = roleStr == null ? UserRole.MEMBER : 
                 roleStr.toUpperCase() == 'MANAGER' ? UserRole.MANAGER :
                 roleStr.toUpperCase() == 'LEADER' ? UserRole.LEADER :
                 UserRole.MEMBER;
          globals.isManager = _role == UserRole.MANAGER;
          _emailController.text = _email;
          _usernameController.text = _username;
          _ageController.text = _age.toString();
          _roleController.text = _role.toString().split('.').last;
          isLoading = false;
        });
      } else {
        print('Failed to load profile: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      try {
        final response = await http.patch(
          Uri.parse('$baseUrl/auth/profile'),
          headers: {
            'Content-Type': 'application/json',
            'tasks_token': widget.accessToken,
          },
          body: json.encode({
            'email': _emailController.text,
            'username': _usernameController.text,
            'age': int.parse(_ageController.text),
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
          setState(() {
            _email = _emailController.text;
            _username = _usernameController.text;
            _age = int.parse(_ageController.text);
            isLoading = false;
            isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        } else {
          print('Failed to update profile: ${response.statusCode}');
          print('Response body: ${response.body}');
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      } catch (e) {
        print('Error updating profile: $e');
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'tasks_token': widget.accessToken,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        // Navigate to login screen
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        print('Failed to logout: ${response.statusCode}');
        print('Response body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to logout')),
        );
      }
    } catch (e) {
      print('Error during logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred during logout')),
      );
    }
  }

  void _toggleEditMode() {
    setState(() {
      isEditing = !isEditing;
      if (!isEditing) {
        // Reset form when canceling edit
        _emailController.text = _email;
        _usernameController.text = _username;
        _ageController.text = _age.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      enabled: isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your age';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _roleController,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      enabled: false, // Always disabled for role
                    ),
                    const SizedBox(height: 24.0),
                    if (!isEditing)
                      ElevatedButton(
                        onPressed: _toggleEditMode,
                        child: const Text('Edit Profile'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _updateProfile,
                              child: const Text('Save'),
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _toggleEditMode,
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
} 