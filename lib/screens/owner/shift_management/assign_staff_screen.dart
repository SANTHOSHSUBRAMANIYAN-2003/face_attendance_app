import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/session_provider.dart';

class AssignStaffScreen extends StatefulWidget {
  const AssignStaffScreen({super.key});

  @override
  State<AssignStaffScreen> createState() => _AssignStaffScreenState();
}

class _AssignStaffScreenState extends State<AssignStaffScreen> {
  final ApiService _api = ApiService();
  
  List<dynamic> _shifts = [];
  List<dynamic> _staffList = [];
  
  String? _selectedShiftId;
  Set<String> _selectedStaffIds = {};
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId;
    if (companyId != null) {
      final shifts = await _api.getShifts(companyId.toString());
      final staff = await _api.getAllStaff(companyId.toString());
      
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _staffList = staff;
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _assignStaff() async {
    if (_selectedShiftId == null || _selectedStaffIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a shift and at least one staff member")));
      return;
    }

    setState(() => _isSaving = true);
    
    int successCount = 0;
    
    // Get companyId from provider again or store it in state
    final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId?.toString();
    
    if (companyId == null) {
       setState(() => _isSaving = false);
       return;
    }

    for (String staffId in _selectedStaffIds) {
      final success = await _api.assignStaffToShift(staffId, _selectedShiftId!, companyId);
      if (success) successCount++;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Assigned $successCount staff members successfully!")));
      // Optional: Clear selection
      setState(() {
         _selectedStaffIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift Dropdown
          DropdownButtonFormField<String>(
            value: _selectedShiftId,
            hint: const Text("Select Shift"),
            items: _shifts.map<DropdownMenuItem<String>>((shift) {
              return DropdownMenuItem<String>(
                value: shift['shiftid'].toString(),
                child: Text("${shift['shiftname']} (${shift['shiftstart']} - ${shift['shiftendtime']})"),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedShiftId = val);
            },
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15)),
          ),
          
          const SizedBox(height: 20),
          const Text("Select Staff to Assign:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          

          Expanded(
            child: ListView.builder(
              itemCount: _staffList.length,
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                final String staffId = staff['staffid'].toString();
                final bool isSelected = _selectedStaffIds.contains(staffId);

                return CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(staff['name'] ?? 'Unknown'),
                  subtitle: Text("${staff['staffcode'] ?? ''}\n${staff['shiftname'] ?? 'Not Assigned'} (${staff['shiftstart'] ?? ''}-${staff['shiftendtime'] ?? ''})"),
                  isThreeLine: true,
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedStaffIds.add(staffId);
                      } else {
                        _selectedStaffIds.remove(staffId);
                      }
                    });
                  },
                );
              },
            ),
          ),
          
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _assignStaff,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Assign Staff"),
            ),
          ),
        ],
      ),
    );
  }
}
