import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import 'staff_registration_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _staffList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;
    if (companyId != null) {
      final list = await _api.getAllStaff(companyId.toString());
      if (mounted) {
        setState(() {
          _staffList = list.where((s) => s['active'] == 'Y' || s['active'] == null).toList();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Staff"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _staffList.isEmpty
          ? const Center(child: Text("No Staff Found"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StaffRegistrationScreen(staffToEdit: staff),
                        ),
                      );
                      if (result == true) {
                        _fetchStaff();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            backgroundColor: Colors.deepPurple.shade100,
                            child: Text(
                              staff['name']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        staff['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (staff['fieldworker'] == 'Y')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.amber.shade700),
                                        ),
                                        child: Text(
                                          "FIELD WORKER",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text("Code: ${staff['staffcode']}"),
                                if (staff['phone'] != null &&
                                    staff['phone'].toString().isNotEmpty)
                                  Text("Phone: ${staff['phone']}"),
                                const SizedBox(height: 2),
                                Text(
                                  "Shift: ${staff['shiftname'] ?? 'Not Assigned'}",
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (staff['shiftstart'] != null &&
                                    staff['shiftstart'].toString().isNotEmpty)
                                  Text(
                                    "${staff['shiftstart']} - ${staff['shiftendtime']}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Track toggle + location icon
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Track",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              Switch(
                                value:
                                    staff['is_tracking_active'] == '1' ||
                                    staff['is_tracking_active'] == 1 ||
                                    staff['is_tracking_active'] == true,
                                onChanged: (val) async {
                                  final companyId =
                                      Provider.of<SessionProvider>(
                                        context,
                                        listen: false,
                                      ).currentUser?.companyId;
                                  final success = await _api.toggleTracking(
                                    staff['staffid'].toString(),
                                    companyId.toString(),
                                    val ? 'START' : 'STOP',
                                  );
                                  if (success) {
                                    _fetchStaff();
                                  }
                                },
                                activeColor: Colors.deepPurple,
                              ),
                            ],
                          ),
                          if (staff['is_tracking_active'] == '1' ||
                              staff['is_tracking_active'] == 1 ||
                              staff['is_tracking_active'] == true)
                            IconButton(
                              icon: const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 28,
                              ),
                              tooltip: "View Live Location",
                              onPressed: () async {
                                final companyId = Provider.of<SessionProvider>(
                                  context,
                                  listen: false,
                                ).currentUser?.companyId;
                                final locationData = await _api
                                    .getLatestLiveLocation(
                                      staff['staffid'].toString(),
                                      companyId.toString(),
                                    );
                                if (locationData != null) {
                                  final lat = locationData['latitude'];
                                  final lng = locationData['longitude'];
                                  final url = Uri.parse(
                                    "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Could not open Maps"),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "No location ping logged yet!",
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
