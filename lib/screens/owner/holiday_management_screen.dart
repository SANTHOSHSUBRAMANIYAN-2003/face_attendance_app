import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/session_provider.dart';

class HolidayManagementScreen extends StatefulWidget {
  const HolidayManagementScreen({super.key});

  @override
  State<HolidayManagementScreen> createState() => _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends State<HolidayManagementScreen> {
  final ApiService _api = ApiService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<String> _holidays = {};
  Set<String> _pendingHolidays = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId;
    if (companyId != null) {
      final holidays = await _api.getHolidays(companyId.toString());
      if (mounted) {
        setState(() {
          _holidays = holidays.toSet(); 
          _isLoading = false;
        });
      }
    }
  }

  void _handleDateSelection(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    setState(() {
      if (_holidays.contains(dateStr)) {
        // Option to remove existing holiday?
        // For now, let's just show a snackbar or allow removing via long press or similar.
        // User asked for "selects date need to appear below".
        // Let's allow selecting it into "Pending Removal"?
        // Or strictly follow "Mark as Holiday" implies ADDING.
        // Let's assume this flow is for adding.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This date is already a holiday.")));
      } else {
        if (_pendingHolidays.contains(dateStr)) {
          _pendingHolidays.remove(dateStr);
        } else {
          _pendingHolidays.add(dateStr);
        }
      }
    });
  }

  Future<void> _saveHolidays() async {
    final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId;
    if (companyId == null || _pendingHolidays.isEmpty) return;

    setState(() => _isLoading = true);

    final success = await _api.manageHolidaysBatch(_pendingHolidays.toList(), companyId.toString(), "ADD");

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Holidays added successfully!")));
        setState(() {
          _holidays.addAll(_pendingHolidays);
          _pendingHolidays.clear();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add holidays")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Holiday Management"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                availableCalendarFormats: const { CalendarFormat.month: 'Month' },
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _handleDateSelection(selectedDay);
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final dateStr = day.toIso8601String().split('T')[0];
                    if (_holidays.contains(dateStr)) {
                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle),
                        child: Text(
                          day.day.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    if (_pendingHolidays.contains(dateStr)) {
                       return Container(
                        margin: const EdgeInsets.all(4.0),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle),
                        child: Text(
                          day.day.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: Column(
                  children: [
                     const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Selected Dates to Add:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: _pendingHolidays.isEmpty 
                        ? const Center(child: Text("No dates selected"))
                        : ListView(
                            children: _pendingHolidays.map((date) => ListTile(
                              title: Text(date),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _pendingHolidays.remove(date);
                                  });
                                },
                              ),
                            )).toList(),
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _pendingHolidays.isEmpty ? null : _saveHolidays,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text("Mark as Holiday"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
