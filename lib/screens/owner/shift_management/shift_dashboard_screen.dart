import 'package:flutter/material.dart';
import 'create_shift_screen.dart';
import 'assign_staff_screen.dart';

class ShiftDashboardScreen extends StatefulWidget {
  const ShiftDashboardScreen({super.key});

  @override
  State<ShiftDashboardScreen> createState() => _ShiftDashboardScreenState();
}

class _ShiftDashboardScreenState extends State<ShiftDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shift Management"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,

          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: "Create Shift", icon: Icon(Icons.add_alarm)),
            Tab(text: "Assign Staff", icon: Icon(Icons.people_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CreateShiftScreen(),
          AssignStaffScreen(),
        ],
      ),
    );
  }
}
