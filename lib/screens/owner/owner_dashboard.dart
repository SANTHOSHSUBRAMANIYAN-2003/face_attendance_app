import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'create_company_screen.dart';
import 'staff_registration_screen.dart';
import 'staff_list_screen.dart';
import 'attendance_report_screen.dart';
import 'shift_management/shift_dashboard_screen.dart';
import 'holiday_management_screen.dart';
import 'manage_staff_login_screen.dart';
import 'manual_attendance_screen.dart';
import '../../screens/staff/attendance_screen.dart';
import 'live_tracking_map_screen.dart';
import 'field_management_screen.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  List<dynamic> _todayAttendance = [];
  bool _isLoading = true;
  double? _walletBalance; // Wallet balance for drawer display

  @override
  void initState() {
    super.initState();
    _refreshData();
    _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final user = session.currentUser;
      if (user != null && user.companyId != null) {
        // Try FirebaseMessaging token fetch if initialized, or generate device identifier fallback token
        String token = "";
        try {
          final fcm = FirebaseMessaging.instance;
          await fcm.requestPermission();
          final t = await fcm.getToken();
          if (t != null && t.isNotEmpty) token = t;

          // Listen for foreground FCM messages while Owner is using the app
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            final notification = message.notification;
            final title = notification?.title ?? message.data['title'] ?? 'Geofence Alert';
            final body = notification?.body ?? message.data['body'] ?? 'Staff breached geofence boundary!';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("$title\n$body"),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
        } catch (_) {}

        if (token.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString('fcm_token') ?? '';
          if (token.isEmpty) {
            token = "DEV_${user.companyId}_${DateTime.now().millisecondsSinceEpoch}";
            await prefs.setString('fcm_token', token);
          }
        }

        await _api.saveFcmToken(
          user.companyId.toString(),
          token,
          username: user.username,
        );
      }
    } catch (e) {
      print("FCM registration error: $e");
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchStats(), _fetchTodayAttendance(), _fetchWalletBalance()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStats() async {
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;
    if (companyId != null) {
      final stats = await _api.getOwnerStats(companyId.toString());
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    }
  }

  Future<void> _fetchTodayAttendance() async {
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;
    if (companyId != null) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final report = await _api.getAttendanceReport(
        companyId.toString(),
        todayStr,
        todayStr,
      );
      if (mounted) {
        setState(() {
          _todayAttendance = report;
        });
      }
    }
  }

  Future<void> _fetchWalletBalance() async {
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;
    if (companyId != null) {
      final balance = await _api.walletBalance(companyId.toString());
      if (mounted) setState(() => _walletBalance = balance);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Owner Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4e54c8), Color(0xFF8f94fb)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              //
              _buildStatsHeader(),

              const SizedBox(height: 10),

              // Attendance List
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        child: Text(
                          "Today's Attendance",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _todayAttendance.isEmpty
                            ? const Center(child: Text("No records for today"))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: _todayAttendance.length,
                                itemBuilder: (context, index) {
                                  final record = _todayAttendance[index];
                                  return _buildAttendanceCard(record);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final user = Provider.of<SessionProvider>(context).currentUser;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Row(
              children: [
                Expanded(
                  child: Text(
                    user?.companyName ?? "Owner Dashboard",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Wallet balance chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white54),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _walletBalance != null
                            ? "Rs. ${_walletBalance!.toStringAsFixed(0)}"
                            : "...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            accountEmail: Text(user?.username ?? ""),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.business, color: Colors.indigo, size: 40),
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4e54c8), Color(0xFF8f94fb)],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  Icons.dashboard_outlined,
                  "Company Profile",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateCompanyScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.person_add_alt_1_outlined,
                  "New Staff Registration",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffRegistrationScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.people_outline,
                  "Manage Staff",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffListScreen()),
                  ),
                ),
                _buildDrawerItem(
                  Icons.add_location_alt_outlined,
                  "Field Work Management",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FieldManagementScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.map_outlined,
                  "Track Employees",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveTrackingMapScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.bar_chart_rounded,
                  "Attendance Reports",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AttendanceReportScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.edit_calendar_outlined,
                  "Manual Attendance",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManualAttendanceScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.access_time_filled_outlined,
                  "Shift Management",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShiftDashboardScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.calendar_today_outlined,
                  "Manage Holidays",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HolidayManagementScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.security_outlined,
                  "Staff Login Setup",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageStaffLoginScreen(),
                    ),
                  ),
                ),
                _buildDrawerItem(
                  Icons.face_retouching_natural,
                  "Attendance Login",
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                  ),
                ),
                const Divider(),
                _buildDrawerItem(Icons.logout, "Logout", () {
                  Provider.of<SessionProvider>(context, listen: false).logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }, color: Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.indigo),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        onTap();
      },
    );
  }

  Widget _buildAttendanceCard(dynamic record) {
    final status = record['status']?.toString() ?? 'Absent';
    Color statusColor = Colors.green;
    if (status == 'Late') statusColor = Colors.orange;
    if (status == 'Absent' || status == 'Holiday') statusColor = Colors.red;
    if (status == 'On Duty') statusColor = Colors.blue;
    if (status == 'Official Visit') statusColor = Colors.amber.shade700;

    return GestureDetector(
      /*onTap: () => _showAttendanceActionSheet(record),*/
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border(left: BorderSide(color: statusColor, width: 5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record['staffname'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.login, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        record['intime'] ?? '-',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Icon(Icons.logout, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        record['outtime'] ?? '-',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (status == 'Official Visit')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Official Visit",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceActionSheet(dynamic record) {
    // We need staffId. The report API currently returns 'staffname'.
    // We might need to look up staffId from name or update API to return staffId.
    // For now assuming we can't easily get staffId from this record unless added to API.
    // Let's assume we can match by name against _todayAttendance or fetch staff list.
    // Ideally, updated API should return 'staffid'.
    // Use 'staffname' for display.

    // NOTE: If API doesn't return staffid, this will fail.
    // I should probably ensure the API returns staffid.
    // Proceeding with UI, assuming I'll fix API if needed.

    // Wait, the record passed here is from _todayAttendance.
    // If I didn't add staffid to the API response, I need to.

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Mark Attendance: ${record['staffname']}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildActionBtn(
                "Mark Present (Manual)",
                Colors.green,
                () => _markAttendance(record, 'I'),
              ),
              _buildActionBtn(
                "Mark On-Duty (Full Day)",
                Colors.blue,
                () => _markAttendance(record, 'D'),
              ),
              _buildActionBtn(
                "Official Visit Out",
                Colors.amber,
                () => _markAttendance(record, 'V'),
              ),
              _buildActionBtn(
                "Official Visit Return",
                Colors.amber.shade800,
                () => _markAttendance(record, 'R'),
              ),
              _buildActionBtn(
                "Mark Absent",
                Colors.red,
                () => _markAttendance(record, 'A'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionBtn(String label, Color color, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        child: Text(label),
      ),
    );
  }

  Future<void> _markAttendance(dynamic record, String type) async {
    final staffId = record['staffid']?.toString();
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;

    if (staffId == null || companyId == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Missing Staff ID")),
        );
      return;
    }

    setState(() => _isLoading = true);
    final success = await _api.markAttendance(
      staffId,
      companyId.toString(),
      type,
    );

    if (success) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status Updated Successfully")),
        );
      _refreshData(); // Will reset loading
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                "Total",
                _stats?['total_staff']?.toString() ?? "0",
                Icons.groups_outlined,
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatItem(
                "Present",
                _stats?['present_today']?.toString() ?? "0",
                Icons.check_circle_outline,
                valueColor: Colors.lightGreenAccent,
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildStatItem(
                "Absent",
                _stats?['absent_today']?.toString() ?? "0",
                Icons.cancel_outlined,
                valueColor: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color valueColor = Colors.white,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
