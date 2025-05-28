import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final url = Uri.parse('http://localhost:8000/api/auth/login'); // Updated API endpoint
      final headers = {'Content-Type': 'application/json'};
      final body = json.encode({
        'username': _emailController.text.trim(), // Using username as per API, assuming email is username
        'password': _passwordController.text,
      });

      try {
        final response = await http.post(url, headers: headers, body: body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Login successful
          final responseData = json.decode(response.body);
          final accessToken = responseData['accessToken'];
          final userId = responseData['user']['id'];
          print('Login successful. Access Token: $accessToken');
          // TODO: Store the access token securely (e.g., using flutter_secure_storage)
          // TODO: Navigate to the main screen
          Navigator.pushReplacementNamed(
            context,
            '/main',
            arguments: {
              'userId': userId,
              'accessToken': accessToken,
            },
          );
        } else if (response.statusCode == 401) {
          // Unauthorized
          setState(() {
            _errorMessage = 'Invalid credentials';
          });
        } else {
          // Other errors
          setState(() {
            _errorMessage = 'Login failed. Please try again.';
             print('Login failed with status code: ${response.statusCode}');
             print('Response body: ${response.body}');
          });
        }
      } catch (e) {
        // Network or other errors
        setState(() {
          _errorMessage = 'An error occurred: ${e.toString()}';
           print('Error during login: $e');
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    // Basic email format validation
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                       return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.0),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Login'),
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 