import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../globale.dart' as globals;

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
  String? _errorMessage;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final url = Uri.parse('$baseUrl/auth/login');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': _emailController.text,
            'password': _passwordController.text,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Login successful
          final responseData = json.decode(response.body);
          final accessToken = responseData['accessToken'];
          final userId = responseData['user']['id'];
          final roleStr = responseData['user']['role'] as String?;
          globals.isManager = roleStr != null && roleStr.toUpperCase() == 'MANAGER';
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Welcome',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 40.0),

                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                  ),
                  keyboardType: TextInputType.emailAddress,
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
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),

                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 15.0),
                     textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Login'),
                ),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 20.0),
                TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password functionality
                  },
                  child: Text('Forgot Password?', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Implement sign up functionality
                  },
                  child: Text('Don\'t have an account? Sign Up', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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