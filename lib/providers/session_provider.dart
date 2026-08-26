import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { owner, staff }

class User {
  final String username;
  final UserRole role;
  final int companyId;
  final String? staffName; // Only for staff
  final String? companyName; // Added for Owner display
  final String? address1;
  final String? address2;
  final String? address3;
  final String? phone;
  final String? staffPrefix;

  User({
    required this.username,
    required this.role,
    required this.companyId,
    this.staffName,
    this.companyName,
    this.address1,
    this.address2,
    this.address3,
    this.phone,
    this.staffPrefix,
  });
}

class SessionProvider with ChangeNotifier {
  User? _currentUser;
  
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> login(String username, String role, int companyId, {String? staffName, String? companyName, String? address1, String? address2, String? address3, String? phone, String? staffPrefix}) async {
    _currentUser = User(
      username: username,
      role: role == 'O' ? UserRole.owner : UserRole.staff,
      companyId: companyId,
      staffName: staffName,
      companyName: companyName,
      address1: address1,
      address2: address2,
      address3: address3,
      phone: phone,
      staffPrefix: staffPrefix,
    );
    notifyListeners();
    
    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('role', role);
    await prefs.setInt('companyId', companyId);
    if (staffName != null) await prefs.setString('staffName', staffName);
    if (companyName != null) await prefs.setString('companyName', companyName);
    if (address1 != null) await prefs.setString('address1', address1);
    if (address2 != null) await prefs.setString('address2', address2);
    if (address3 != null) await prefs.setString('address3', address3);
    if (phone != null) await prefs.setString('phone', phone);
    if (staffPrefix != null) await prefs.setString('staffPrefix', staffPrefix);
  }

  Future<void> updateCompanyDetails({ required String address1, required String address2, required String address3, required String phone, String? companyName, String? staffPrefix }) async {
    if (_currentUser == null) return;
    
    // Create new user object with updated fields
    _currentUser = User(
      username: _currentUser!.username,
      role: _currentUser!.role,
      companyId: _currentUser!.companyId,
      staffName: _currentUser!.staffName,
      companyName: companyName ?? _currentUser!.companyName, // Update if provided
      address1: address1,
      address2: address2,
      address3: address3,
      phone: phone,
      staffPrefix: staffPrefix ?? _currentUser!.staffPrefix, // Update if provided
    );
    notifyListeners();

    // Persist updates
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('address1', address1);
    await prefs.setString('address2', address2);
    await prefs.setString('address3', address3);
    await prefs.setString('phone', phone);
    if (companyName != null) await prefs.setString('companyName', companyName);
    if (staffPrefix != null) await prefs.setString('staffPrefix', staffPrefix);
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('username')) {
      _currentUser = User(
        username: prefs.getString('username')!,
        role: prefs.getString('role') == 'O' ? UserRole.owner : UserRole.staff,
        companyId: prefs.getInt('companyId')!,
        staffName: prefs.getString('staffName'),
        companyName: prefs.getString('companyName'),
        address1: prefs.getString('address1'),
        address2: prefs.getString('address2'),
        address3: prefs.getString('address3'),
        phone: prefs.getString('phone'),
        staffPrefix: prefs.getString('staffPrefix'),
      );
      notifyListeners();
    }
  }
}
