import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';

class LateHoursReportScreen extends StatefulWidget {
  const LateHoursReportScreen({super.key});

  @override
  State<LateHoursReportScreen> createState() => _LateHoursReportScreenState();
}

class _LateHoursReportScreenState extends State<LateHoursReportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _toDate = DateTime.now();
  final ApiService _api = ApiService();
  bool _isLoading = false;

  // One summary row per staff
  List<_StaffSummary> _summaries = [];

  Future<void> _fetchData() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final companyId = session.currentUser?.companyId.toString();
    if (companyId == null) return;

    setState(() => _isLoading = true);

    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

      // Fetch all 3 sources in parallel
      final results = await Future.wait([
        _api.getHolidays(companyId),
        _api.getAllStaff(companyId),
        _api.getAttendanceReport(companyId, fromStr, toStr),
      ]);

      final Set<String> holidaySet = (results[0] as List<dynamic>)
          .cast<String>()
          .toSet();
      final List<dynamic> allStaff = results[1] as List<dynamic>;
      final List<dynamic> attendance = results[2] as List<dynamic>;

      // Build date range
      List<DateTime> dateRange = [];
      DateTime cur = _fromDate;
      while (!cur.isAfter(_toDate)) {
        dateRange.add(cur);
        cur = cur.add(const Duration(days: 1));
      }

      int holidaysInRange = 0;
      for (var d in dateRange) {
        if (holidaySet.contains(DateFormat('yyyy-MM-dd').format(d))) {
          holidaysInRange++;
        }
      }
      int workingDaysInRange = dateRange.length - holidaysInRange;

      // Group attendance by staffname -> Set of dates they attended
      // Map<staffname, Map<date, record>>
      Map<String, Map<String, Map<String, dynamic>>> byStaff = {};
      for (var r in attendance) {
        String name = r['staffname'].toString();
        String date = r['date'].toString();
        byStaff.putIfAbsent(name, () => {});
        byStaff[name]![date] = Map<String, dynamic>.from(r);
      }

      List<_StaffSummary> summaries = [];

      for (var staff in allStaff) {
        final staffName = staff['name'].toString();
        final staffRecords = byStaff[staffName] ?? {};

        int presentCount = 0;
        int absentCount = 0;
        int totalLateMinutes = 0;

        for (var d in dateRange) {
          final dateStr = DateFormat('yyyy-MM-dd').format(d);

          // Skip holidays
          if (holidaySet.contains(dateStr)) continue;

          final rec = staffRecords[dateStr];
          if (rec == null) {
            // No record for this working day = Absent
            absentCount++;
          } else {
            final status = rec['status'] ?? '';
            if (status == 'Present' || status == 'Late') presentCount++;
            if (status == 'Absent') absentCount++;

            if (status == 'Late') {
              final inTime = rec['intime']?.toString() ?? '-';
              final shiftStart = rec['shiftstart']?.toString() ?? '-';
              if (inTime != '-' && shiftStart != '-') {
                try {
                  final inParts = inTime.split(':');
                  final shParts = shiftStart.split(':');
                  final inMinutes =
                      int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
                  final shMinutes =
                      int.parse(shParts[0]) * 60 + int.parse(shParts[1]);
                  final diff = inMinutes - shMinutes;
                  if (diff > 0) totalLateMinutes += diff;
                } catch (_) {}
              }
            }
          }
        }

        summaries.add(
          _StaffSummary(
            staffName: staffName,
            totalWorkingDays: workingDaysInRange,
            totalHolidays: holidaysInRange,
            totalPresent: presentCount,
            totalAbsent: absentCount,
            totalLateMinutes: totalLateMinutes,
          ),
        );
      }

      summaries.sort((a, b) => a.staffName.compareTo(b.staffName));

      setState(() {
        _summaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Late Hours Report"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDateChip("From", _fromDate, true),
                    const Icon(Icons.arrow_forward, color: Colors.grey),
                    _buildDateChip("To", _toDate, false),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchData,
                    icon: const Icon(Icons.bar_chart),
                    label: const Text("GENERATE REPORT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _summaries.isEmpty
                ? const Center(child: Text("Select dates and click Generate"))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          Colors.deepPurple.shade50,
                        ),
                        columnSpacing: 18,
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columns: const [
                          DataColumn(
                            label: Text(
                              "Staff Name",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Working\nDays",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Holidays",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Present",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Absent",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Total Late\nHours",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                        rows: _summaries.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  s.staffName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Center(
                                  child: Text(
                                    s.totalWorkingDays.toString(),
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Center(
                                  child: Text(
                                    s.totalHolidays.toString(),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Center(
                                  child: Text(
                                    s.totalPresent.toString(),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Center(
                                  child: Text(
                                    s.totalAbsent.toString(),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Center(
                                  child: Text(
                                    s.totalLateMinutes == 0
                                        ? '-'
                                        : _formatMinutes(s.totalLateMinutes),
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, DateTime date, bool isFrom) {
    return TextButton.icon(
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text("$label: ${DateFormat('dd MMM').format(date)}"),
      onPressed: () => _selectDate(context, isFrom),
    );
  }
}

class _StaffSummary {
  final String staffName;
  final int totalWorkingDays;
  final int totalHolidays;
  final int totalPresent;
  final int totalAbsent;
  final int totalLateMinutes;

  const _StaffSummary({
    required this.staffName,
    required this.totalWorkingDays,
    required this.totalHolidays,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalLateMinutes,
  });
}
