import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/session_provider.dart';

class CreateShiftScreen extends StatefulWidget {
  const CreateShiftScreen({super.key});

  @override
  State<CreateShiftScreen> createState() => _CreateShiftScreenState();
}

class _CreateShiftScreenState extends State<CreateShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  
  bool _isLoading = false;
  final ApiService _api = ApiService();

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute:00";
  }

  List<dynamic> _shifts = [];
  
  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId;
    if (companyId != null) {
      final shifts = await _api.getShifts(companyId.toString());
      if (mounted) setState(() => _shifts = shifts);
    }
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId;
    
    if (companyId != null) {
      final success = await _api.createShift(
        _nameController.text,
        _formatTime(_startTime),
        _formatTime(_endTime),
        companyId.toString(),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shift Created Successfully!")));
          _nameController.clear();
          _fetchShifts(); // Refresh List
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create shift")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Creation Form
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Shift Name (e.g., Morning Shift)", border: OutlineInputBorder()),
                  validator: (val) => val == null || val.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text("Start Time"),
                        subtitle: Text(_startTime.format(context)),
                        trailing: const Icon(Icons.access_time),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.grey)),
                        onTap: () => _selectTime(context, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ListTile(
                        title: const Text("End Time"),
                        subtitle: Text(_endTime.format(context)),
                        trailing: const Icon(Icons.access_time),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.grey)),
                        onTap: () => _selectTime(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveShift,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Create Shift"),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Divider(thickness: 1),
        
        // List of Shifts
        Expanded(
          child: _shifts.isEmpty 
             ? const Center(child: Text("No Shifts Created Yet", style: TextStyle(color: Colors.grey)))
             : ListView.builder(
                 itemCount: _shifts.length,
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 itemBuilder: (context, index) {
                    final shift = _shifts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade100,
                          child: Icon(Icons.access_time, color: Colors.deepPurple),
                        ),
                        title: Text(shift['shiftname'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${shift['shiftstart']} - ${shift['shiftendtime']}"),
                        trailing: Chip(label: Text("ID: ${shift['shiftid']}"), backgroundColor: Colors.grey[200]),
                      ),
                    );
                 },
               ),
        )
      ],
    );
  }
}
