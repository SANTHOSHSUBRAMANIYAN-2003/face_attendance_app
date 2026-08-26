import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';

class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({super.key});

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  final ApiService _api = ApiService();
  bool _isLoading = false;
  List<dynamic> _attendanceList = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final companyId = session.currentUser?.companyId.toString();
    if (companyId == null) return;

    setState(() => _isLoading = true);
    
    // We fetching report for single day to get everyone's status
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final data = await _api.getAttendanceReport(companyId, dateStr, dateStr);

    if (mounted) {
      setState(() {
        _attendanceList = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Can mark for today or past
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchData();
    }
  }

  void _showMarkingSheet(dynamic record) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Mark for ${DateFormat('dd MMM').format(_selectedDate)}: ${record['staffname']}", 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 20),
              _buildActionBtn("Mark Present", Colors.green, () => _markStatus(record, 'I')),
              _buildActionBtn("Mark On-Duty (Full Day)", Colors.blue, () => _markStatus(record, 'D')),
              _buildActionBtn("Official Visit Out", Colors.amber, () => _markStatus(record, 'V')),
              _buildActionBtn("Official Visit Return", Colors.amber.shade800, () => _markStatus(record, 'R')),
              _buildActionBtn("Mark Absent", Colors.red, () => _markStatus(record, 'A')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Future<void> _markStatus(dynamic record, String type) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final companyId = session.currentUser?.companyId.toString();
    final staffId = record['staffid']?.toString();

    if (companyId == null || staffId == null) return;
    
    Navigator.pop(context); // Close sheet

    setState(() => _isLoading = true);

    // If Date is NOT Today, we default time to 09:00:00 or similar? 
    // Actually the API handles "If date is provided but time is not..." logic.
    // But for 'Present' (I) usually we want a time. 
    // If it is 'On Duty' (D) or 'Absent' (A), time matters less but we still need a record.
    // We will send just the DATE. The API default logic (09:00 for past) should suffice for D/A.
    // For 'I' (Present) in past, 9:00 is a fair assumption for manual entry.
    
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    // Optional: If Today, maybe send current time? 
    // API logic: if time is null and date is today => uses Now. 
    // So sending just date is perfectly fine.

    final success = await _api.markAttendance(
      staffId, 
      companyId, 
      type,
      date: dateStr
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated Successfully")));
      _fetchData(); // Refresh list to show new status
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manual Attendance"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Date Picker Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Select Date:", style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd MMM yyyy').format(_selectedDate), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  onPressed: () => _selectDate(context),
                )
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _attendanceList.isEmpty 
                  ? const Center(child: Text("No staff found"))
                  : ListView.builder(
                      itemCount: _attendanceList.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final item = _attendanceList[index];
                        final status = item['status'] ?? 'Absent';
                        
                        Color statusColor = Colors.grey;
                        if (status == 'Present') statusColor = Colors.green;
                        if (status == 'Late') statusColor = Colors.orange;
                        if (status == 'On Duty') statusColor = Colors.blue;
                        if (status == 'Official Visit') statusColor = Colors.amber;
                        if (status == 'Absent') statusColor = Colors.red;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(item['staffname'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Current: $status"),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor)
                              ),
                              child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                            ),
                            onTap: () => _showMarkingSheet(item),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
