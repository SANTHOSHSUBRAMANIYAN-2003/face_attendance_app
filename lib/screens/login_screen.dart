import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/session_provider.dart';
import 'owner/owner_dashboard.dart';
import 'staff/attendance_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  
  // Temporary storage for signup data to bridge API gaps
  String? _pendingSignupPrefix;
  String? _pendingCompanyName;

  Future<void> _handleLogin() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both username and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userData = await _apiService.login(username, password);

      if (userData != null) {
        final role = userData['logintype'];
        // Parse companyId (API returns string "1")
        final companyId = int.tryParse(userData['companyid'].toString()) ?? 0;
        
        // Robust Key Access (Handle mismatch case)
        // Robust Key Access (Handle mismatch case) with Fallback to pending signup data
        final companyName = (userData['companyname'] ?? userData['CompanyName'] ?? userData['companyName'])?.toString() ?? _pendingCompanyName;
        final staffPrefix = (userData['staffprefix'] ?? userData['StaffPrefix'] ?? userData['staffPrefix'])?.toString() ?? _pendingSignupPrefix;

        if (mounted) {
          await Provider.of<SessionProvider>(context, listen: false).login(
            username,
            role,
            companyId,
            companyName: companyName,
            staffPrefix: staffPrefix,
          );

          if (role == 'O') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OwnerDashboard()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid Credentials or Connection Error")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA), // Soft Blue
              Color(0xFF764BA2), // Deep Purple
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo or Icon
                const Icon(Icons.face_retouching_natural, size: 80, color: Colors.white),
                const SizedBox(height: 10),
                const Text(
                  "Face Attendance",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 40),

                // Glass/Card Container
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9), // Slightly transparent white
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Username
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: "Username",
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF764BA2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "LOGIN",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUpScreen()),
                    );

                    if (result != null && result is Map) {
                       setState(() {
                          _usernameController.text = result['username'] ?? '';
                          _passwordController.text = result['password'] ?? '';
                       });
                       
                       // Store the signup prefix temporarily for the next login attempt
                       // This bridges the gap if the API doesn't return it yet
                       if (result['staffPrefix'] != null) {
                          // We attach it to the widget state or a static/global? 
                          // Simplest is to save it to SharedPreferences right here so _handleLogin can Find it.
                          // But we are in a widget. 
                          // Let's use a specialized method in SessionProvider? No, too complex.
                          // We will just pass it to the Login logic via a member variable.
                          _pendingSignupPrefix = result['staffPrefix'];
                          _pendingCompanyName = result['companyName'];
                       }
                    }
                  },
                  child: const Text(
                    "Don't have an account? Sign Up",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Powered by NMS Payroll",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
