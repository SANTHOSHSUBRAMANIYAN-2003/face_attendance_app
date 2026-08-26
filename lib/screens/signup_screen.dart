import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _companyDataController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _staffPrefixController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpEnteredController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _generatedOtp; // stored locally for verification

  // Send OTP via WappBlaster webhook
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 10-digit mobile number")),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    // Generate random 4-digit OTP
    final otp = (1000 + Random().nextInt(9000)).toString();
    _generatedOtp = otp;

    try {
      final url = Uri.parse(
        "https://webhooks.wappblaster.com/webhook/66fce4e576f37bade3f6ad4c"
        "?number=$phone&message=microotp~$otp",
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() => _otpSent = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("OTP sent to $phone via WhatsApp!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to send OTP. Try again.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _handleSignUp() async {
    final company = _companyDataController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    final prefix = _staffPrefixController.text.trim().toUpperCase();
    final phone = _phoneController.text.trim();
    final enteredOtp = _otpEnteredController.text.trim();

    if (company.isEmpty || user.isEmpty || pass.isEmpty || prefix.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    // Validate Staff Prefix (3 Letters, Alphabets only)
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(prefix)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Staff Prefix must be exactly 3 alphabets (e.g., ACC)")),
      );
      return;
    }

    // OTP must be sent and verified
    if (!_otpSent || _generatedOtp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please send and verify OTP first")),
      );
      return;
    }

    if (enteredOtp != _generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid OTP. Please check and try again."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final api = ApiService();
    // Returns the new companyId on success, or null on failure
    final newCompanyId = await api.signUp(
      companyName: company,
      username: user,
      password: pass,
      staffPrefix: prefix,
      phone: phone,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (newCompanyId != null) {
        // Credit Rs.150 signup bonus to the wallet
        await api.walletCredit(
          companyId: newCompanyId.toString(),
          amount: 150.0,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sign Up Successful! Rs.150 bonus credited. Please Login."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, {
          'username': user,
          'password': pass,
          'staffPrefix': prefix,
          'companyName': company,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sign Up Failed. Staff Prefix may already exist.")),
        );
      }
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
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.app_registration, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "Create Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Register your company",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // Glass Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(_companyDataController, "Company Name", Icons.business),
                      const SizedBox(height: 15),
                      _buildTextField(_usernameController, "Username", Icons.person),
                      const SizedBox(height: 15),
                      _buildTextField(_passwordController, "Password", Icons.lock, isPassword: true),
                      const SizedBox(height: 15),
                      _buildTextField(_staffPrefixController, "Staff Prefix (3 Letters)", Icons.badge_outlined,
                          inputType: TextInputType.text),
                      const SizedBox(height: 15),

                      // ---- PHONE + SEND OTP ROW ----
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _phoneController,
                              "Mobile Number",
                              Icons.phone,
                              inputType: TextInputType.phone,
                              isEnabled: !_otpSent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSendingOtp || _otpSent ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _otpSent ? Colors.green : Colors.white,
                                foregroundColor: const Color(0xFF4A00E0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: _isSendingOtp
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(
                                      _otpSent ? "✓ Sent" : "Send OTP",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      // ---- OTP ENTRY (visible after OTP sent) ----
                      if (_otpSent) ...[
                        const SizedBox(height: 15),
                        _buildTextField(
                          _otpEnteredController,
                          "Enter OTP",
                          Icons.verified_user,
                          inputType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: _isSendingOtp ? null : () {
                                setState(() {
                                  _otpSent = false;
                                  _generatedOtp = null;
                                  _otpEnteredController.clear();
                                });
                              },
                              icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                              label: const Text(
                                "Resend OTP",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],


                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4A00E0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text(
                                  "SIGN UP",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    bool isEnabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: inputType,
      enabled: isEnabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.black12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}
