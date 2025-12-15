import 'package:flutter/material.dart';
import 'package:appwrite/models.dart'; // Import for User model
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
  bool _isUnlockMode = false; // Is this a full login or just an unlock?

  @override
  void initState() {
    super.initState();
    _checkForExistingSession();
  }

  // Check if the user was previously logged in
  void _checkForExistingSession() async {
    setState(() => _isLoading = true);
    User? user = await _auth.getCurrentUser();
    setState(() => _isLoading = false);

    if (user != null) {
      // SESSION EXISTS: Go to "Unlock Mode"
      setState(() {
        _isUnlockMode = true;
        _emailController.text = user.email; // Pre-fill email
      });
    }
    // If user is null, we stay in "Full Login Mode" (fields empty)
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill in all fields")));
      return;
    }

    setState(() => _isLoading = true);

    // Call our "Smart Login" (Handles the session collision automatically)
    bool success = await _auth.login(email, password);

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Incorrect Password"), backgroundColor: Colors.red)
      );
    }
  }

  // Allow user to switch account if they are in Unlock Mode
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
      backgroundColor: Color(0xFFF5F5F7),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isUnlockMode ? Icons.lock_outline : Icons.admin_panel_settings, 
                size: 80, 
                color: Color(0xFF673AB7)
              ),
              SizedBox(height: 16),
              
              Text(
                _isUnlockMode ? "Welcome Back" : "Admin Login",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              
              if (_isUnlockMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Enter password to unlock", style: TextStyle(color: Colors.grey)),
                ),

              SizedBox(height: 40),

              // EMAIL FIELD (Locked if Unlock Mode)
              TextField(
                controller: _emailController,
                enabled: !_isUnlockMode, // Disable typing if in unlock mode
                decoration: InputDecoration(
                  labelText: "Email", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  filled: _isUnlockMode, // Grey out background if locked
                  fillColor: Colors.grey[200],
                ),
              ),
              SizedBox(height: 16),

              // PASSWORD FIELD (Always Enabled)
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              SizedBox(height: 24),

              // LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF673AB7), 
                    foregroundColor: Colors.white
                  ),
                  child: _isLoading 
                    ? CircularProgressIndicator(color: Colors.white) 
                    : Text(_isUnlockMode ? "UNLOCK" : "LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              // SWITCH ACCOUNT BUTTON (Only show if in Unlock Mode)
              if (_isUnlockMode)
                TextButton(
                  onPressed: _switchAccount,
                  child: Text("Not you? Switch Account", style: TextStyle(color: Colors.grey)),
                )
            ],
          ),
        ),
      ),
    );
  }
}