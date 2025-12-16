import 'package:flutter/material.dart';
import 'package:appwrite/models.dart';
import '../services/appwrite_service.dart';
import 'admin_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AppwriteService _auth = AppwriteService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isLoading = false;
  bool _isUnlockMode = false;

  @override
  void initState() {
    super.initState();
    _checkForSession();
  }

  void _checkForSession() async {
    setState(() => _isLoading = true);
    User? user = await _auth.getCurrentUser();
    setState(() => _isLoading = false);

    if (user != null) {
      setState(() {
        _isUnlockMode = true;
        _emailController.text = user.email;
      });
    }
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both email and password"))
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Call the updated login method (returns String? error)
    String? error = await _auth.login(email, password);
    
    setState(() => _isLoading = false);

    if (error == null) {
      // Success!
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => AdminScreen())
        );
      }
    } else {
      // Failure - Show the specific error (e.g., Rate Limit)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error), 
            backgroundColor: error.contains("wait") ? Colors.orange[800] : Colors.red,
            duration: const Duration(seconds: 5),
          )
        );
      }
    }
  }

  void _switchAccount() async {
    await _auth.logout();
    setState(() {
      _isUnlockMode = false;
      _emailController.clear();
      _passController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.shield_moon, size: 48, color: Color(0xFF0F172A)),
                const SizedBox(height: 24),
                Text(
                  _isUnlockMode ? "Welcome Back" : "Admin Console",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  _isUnlockMode ? "Enter password to unlock" : "Sign in to manage content",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),
                
                TextField(
                  controller: _emailController,
                  enabled: !_isUnlockMode,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    filled: _isUnlockMode,
                    fillColor: _isUnlockMode ? const Color(0xFFF1F5F9) : Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  onSubmitted: (_) => _handleLogin(),
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isUnlockMode ? "UNLOCK" : "SIGN IN"),
                ),
                
                if (_isUnlockMode) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _switchAccount,
                    child: const Text("Switch Account", style: TextStyle(color: Color(0xFF64748B))),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}