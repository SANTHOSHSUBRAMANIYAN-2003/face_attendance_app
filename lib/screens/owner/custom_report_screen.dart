import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';

class CustomReportScreen extends StatefulWidget {
  const CustomReportScreen({super.key});

  @override
  State<CustomReportScreen> createState() => _CustomReportScreenState();
}

class _CustomReportScreenState extends State<CustomReportScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _toDate = DateTime.now();
  final ApiService _api = ApiService();
  bool _isLoading = false;

  List<dynamic> _staffList = [];
  Set<String> _holidays = {};
  List<dynamic> _attendanceData = [];
  bool _showRelieved = false;

  // Computed Grid Data
  // Map<StaffId, Map<DateString, StatusModel>>
  Map<String, Map<String, _DailyStatus>> _gridData = {};

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchData() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final companyId = session.currentUser?.companyId.toString();

    if (companyId == null) return;

    setState(() => _isLoading = true);

    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

      // 1. Fetch Staff (Rows)
      final staff = await _api.getAllStaff(companyId);

      // 2. Fetch Holidays (To mark holidays)
      final holidays = await _api.getHolidays(companyId);

      // 3. Fetch Attendance (To mark present)
      final attendance = await _api.getAttendanceReport(
        companyId,
        fromStr,
        toStr,
      );

      setState(() {
        // Filter based on _showRelieved checkbox
        if (_showRelieved) {
          _staffList = List.from(staff); // Create a mutable copy
        } else {
          // More robust filtering: only 'Y' or null are considered active
          _staffList = staff.where((s) {
            final active = s['active']?.toString().toUpperCase();
            return active == 'Y' || active == null || active == 'NULL' || active == '';
          }).toList();
        }
        
        _holidays = holidays.toSet();
        _attendanceData = attendance;
        _processGridData();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching data: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _processGridData() {
    // 0. DISCOVERY: If _showRelieved is true, check if any attendance records mention
    // staff not in our _staffList (which likely are relieved staff hidden by the server API).
    if (_showRelieved) {
      for (var record in _attendanceData) {
        String recordName = record['staffname'].toString();
        bool alreadyInList = _staffList.any(
          (s) => s['name'].toString().toLowerCase() == recordName.toLowerCase(),
        );
        if (!alreadyInList) {
          _staffList.add({
            'name': recordName,
            'staffcode': record['staffcode']?.toString() ?? 'REL-?',
            'active': 'N',
            'is_virtual': true,
          });
        }
      }
    }

    _gridData.clear();

    // Create Date Range List
    List<DateTime> dateRange = [];
    DateTime current = _fromDate;
    while (current.isBefore(_toDate) || current.isAtSameMomentAs(_toDate)) {
      dateRange.add(current);
      current = current.add(const Duration(days: 1));
    }

    // Initialize Grid with Absent/Holiday
    for (var staff in _staffList) {
      String staffId = staff['staffcode']
          .toString(); // Using staffcode as key key
      _gridData[staffId] = {};

      for (var date in dateRange) {
        String dateStr = DateFormat('yyyy-MM-dd').format(date);

        if (_holidays.contains(dateStr)) {
          _gridData[staffId]![dateStr] = _DailyStatus(
            status: "Holiday",
            color: Colors.blue.shade100,
          );
        } else {
          _gridData[staffId]![dateStr] = _DailyStatus(
            status: "Absent",
            color: Colors.red.shade50,
          );
        }
      }
    }

    // Fill Present Data
    for (var record in _attendanceData) {
      // Find staff code based on name (Attendance API returns name, Staff List has both)
      // This is a bit risky if names are not unique. Better if Attendance API returned staffcode.
      // Let's rely on matching Name for now as per current API structure.

      String recordName = record['staffname'].toString();
      String recordDate = record['date'].toString();

      // Find matching staff in _staffList
      var staffMatch = _staffList.firstWhere(
        (s) => s['name'].toString().toLowerCase() == recordName.toLowerCase(),
        orElse: () => null,
      );

      if (staffMatch != null) {
        String staffCode = staffMatch['staffcode'].toString();
        if (_gridData.containsKey(staffCode)) {
          String timeRange = "${record['intime']} - ${record['outtime']}";
          if (record['status'] == 'Present' || record['status'] == 'Late') {
            _gridData[staffCode]![recordDate] = _DailyStatus(
              status: record['status'],
              subText: timeRange,
              color: record['status'] == 'Late'
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
            );
          } else if (record['status'] == 'Holiday') {
            _gridData[staffCode]![recordDate] = _DailyStatus(
              status: "Holiday",
              color: Colors.blue.shade100,
            );
          }
        }
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

  @override
  Widget build(BuildContext context) {
    // Generate date columns
    List<DateTime> dateColumns = [];
    DateTime current = _fromDate;
    while (current.isBefore(_toDate) || current.isAtSameMomentAs(_toDate)) {
      dateColumns.add(current);
      current = current.add(const Duration(days: 1));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Grid Report"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              const Text("Relieved", style: TextStyle(fontSize: 12)),
              Checkbox(
                value: _showRelieved,
                activeColor: Colors.white,
                checkColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.white),
                onChanged: (val) {
                  setState(() {
                    _showRelieved = val ?? false;
                  });
                },
              ),
            ],
          ),
        ],
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
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        "From: ${DateFormat('dd MMM').format(_fromDate)}",
                      ),
                      onPressed: () => _selectDate(context, true),
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.grey),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        "To: ${DateFormat('dd MMM').format(_toDate)}",
                      ),
                      onPressed: () => _selectDate(context, false),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _fetchData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("GENERATE REPORT"),
                  ),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: _staffList.isEmpty
                ? const Center(child: Text("Select dates and click Generate"))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          Colors.deepPurple.shade50,
                        ),
                        columnSpacing: 20,
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columns: [
                          const DataColumn(
                            label: Text(
                              "Staff Name",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...dateColumns.map(
                            (d) => DataColumn(
                              label: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('dd MMM').format(d),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEE').format(d),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              "Total\nPresent",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              "Total\nAbsent",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              "Total\nWorking",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          const DataColumn(
                            label: Text(
                              "Total\nHolidays",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                        rows: _staffList.map((staff) {
                          String staffCode = staff['staffcode'].toString();
                          String staffName = staff['name'].toString();

                          int presentCount = 0;
                          int absentCount = 0;

                          List<DataCell> cells = [
                            DataCell(
                              Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 100,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staffName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      staffCode,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ];

                          for (var date in dateColumns) {
                            String dateStr = DateFormat(
                              'yyyy-MM-dd',
                            ).format(date);
                            _DailyStatus status =
                                _gridData[staffCode]?[dateStr] ??
                                _DailyStatus(status: "NA");

                            if (status.status == "Present" ||
                                status.status == "Late")
                              presentCount++;
                            if (status.status == "Absent") absentCount++;

                            cells.add(
                              DataCell(
                                Container(
                                  color: status.color,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                   ),
                                   child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          status.status,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: status.status == "Present"
                                                ? Colors.green.shade800
                                                : (status.status == "Absent"
                                                      ? Colors.red.shade800
                                                      : Colors.blue.shade800),
                                          ),
                                        ),
                                        if (status.subText != null)
                                          Text(
                                            status.subText!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          // Summary Cells
                          int actualHolidaysInRange = 0;
                          for (var d in dateColumns) {
                            if (_holidays.contains(
                              DateFormat('yyyy-MM-dd').format(d),
                            )) {
                              actualHolidaysInRange++;
                            }
                          }
                          int totalWorkingDaysInRange =
                              dateColumns.length - actualHolidaysInRange;

                          cells.add(
                            DataCell(
                              Center(
                                child: Text(
                                  presentCount.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ),
                          );
                          cells.add(
                            DataCell(
                              Center(
                                child: Text(
                                  absentCount.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          );
                          cells.add(
                            DataCell(
                              Center(
                                child: Text(
                                  totalWorkingDaysInRange.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ),
                            ),
                          );
                          cells.add(
                            DataCell(
                              Center(
                                child: Text(
                                  actualHolidaysInRange.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          );

                          return DataRow(cells: cells);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DailyStatus {
  final String status;
  final String? subText;
  final Color? color;

  _DailyStatus({required this.status, this.subText, this.color});
}
