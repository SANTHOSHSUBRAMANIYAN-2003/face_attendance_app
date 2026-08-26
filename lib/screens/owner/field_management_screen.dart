import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';

class FieldManagementScreen extends StatefulWidget {
  const FieldManagementScreen({super.key});

  @override
  State<FieldManagementScreen> createState() => _FieldManagementScreenState();
}

class _FieldManagementScreenState extends State<FieldManagementScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _fields = [];
  List<dynamic> _staffList = [];
  List<dynamic> _assignments = [];

  final _fieldNameController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId?.toString();
    if (companyId != null) {
      final fields = await _api.getFieldLocations(companyId);
      final staff = await _api.getAllStaff(companyId);
      final assignments = await _api.getFieldAssignments(companyId);

      if (mounted) {
        setState(() {
          _fields = fields;
          _staffList = staff;
          _assignments = assignments;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services disabled")));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latController.text = position.latitude.toString();
        _longController.text = position.longitude.toString();
      });
    } catch (e) {
      print("Get location error: $e");
    }
  }

  void _showAddFieldDialog() {
    _fieldNameController.clear();
    _latController.clear();
    _longController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Field Location"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fieldNameController,
                decoration: const InputDecoration(labelText: "Field Name (e.g. Site A)", prefixIcon: Icon(Icons.location_city)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _latController,
                decoration: const InputDecoration(labelText: "Latitude", prefixIcon: Icon(Icons.pin_drop)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _longController,
                decoration: const InputDecoration(labelText: "Longitude", prefixIcon: Icon(Icons.pin_drop_outlined)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text("Use My Current Location"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_fieldNameController.text.isEmpty || _latController.text.isEmpty || _longController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
                return;
              }
              final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId?.toString();
              if (companyId != null) {
                final success = await _api.addFieldLocation(companyId, _fieldNameController.text.trim(), _latController.text.trim(), _longController.text.trim());
                if (mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Field location added successfully"), backgroundColor: Colors.green));
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add field location")));
                  }
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(dynamic field) {
    String? selectedStaffId;
    final fieldWorkers = _staffList.where((s) => s['fieldworker'] == 'Y' || s['active'] == 'Y').toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Assign '${field['fieldname']}' to Staff"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStaffId,
                hint: const Text("Select Staff Member"),
                items: fieldWorkers.map<DropdownMenuItem<String>>((s) {
                  return DropdownMenuItem<String>(
                    value: s['staffid'].toString(),
                    child: Text("${s['name']} (${s['staffcode']})${s['fieldworker'] == 'Y' ? ' - Field' : ''}"),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedStaffId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (selectedStaffId == null) return;
                final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId?.toString();
                if (companyId != null) {
                  final success = await _api.assignFieldToStaff(companyId, field['fieldid'].toString(), selectedStaffId!);
                  if (mounted) {
                    Navigator.pop(ctx);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Field assigned successfully!"), backgroundColor: Colors.green));
                      _loadData();
                    }
                  }
                }
              },
              child: const Text("Assign"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Field Work Management"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFieldDialog,
        icon: const Icon(Icons.add_location_alt),
        label: const Text("Add Field Location"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Fields Section
                  const Text("Defined Field Locations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 8),
                  _fields.isEmpty
                      ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("No field locations defined yet.")))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _fields.length,
                          itemBuilder: (context, index) {
                            final field = _fields[index];
                            final fieldAssignments = _assignments.where((a) => a['fieldid'].toString() == field['fieldid'].toString()).toList();

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ExpansionTile(
                                leading: const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.place, color: Colors.white)),
                                title: Text(field['fieldname'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("Lat: ${field['fieldlat']}, Long: ${field['fieldlong']}\nAssigned Staff: ${fieldAssignments.length}"),
                                trailing: ElevatedButton.icon(
                                  onPressed: () => _showAssignDialog(field),
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: const Text("Assign"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                                ),
                                children: [
                                  if (fieldAssignments.isEmpty)
                                    const Padding(padding: EdgeInsets.all(12), child: Text("No staff assigned to this field.", style: TextStyle(color: Colors.grey)))
                                  else
                                    Column(
                                      children: fieldAssignments.map((assign) {
                                        return ListTile(
                                          leading: const Icon(Icons.person, color: Colors.deepPurple),
                                          title: Text(assign['staffname'].toString()),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                                            tooltip: "Unassign Staff",
                                            onPressed: () async {
                                              final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId?.toString();
                                              if (companyId != null) {
                                                final ok = await _api.unassignFieldFromStaff(companyId, assign['fieldid'].toString(), assign['staffid'].toString());
                                                if (ok) _loadData();
                                              }
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    )
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 24),
                  const Text("Staff Field Worker Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 4),
                  const Text("Enable field worker status to allow staff location tracking and location-based attendance.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _staffList.isEmpty
                      ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("No staff members found.")))
                      : Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _staffList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final staff = _staffList[index];
                              final isFw = (staff['fieldworker'] ?? 'N').toString().toUpperCase() == 'Y';

                              return SwitchListTile(
                                secondary: CircleAvatar(
                                  backgroundColor: isFw ? Colors.deepPurple : Colors.grey.shade300,
                                  child: Icon(
                                    isFw ? Icons.directions_walk : Icons.person_outline,
                                    color: isFw ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                                title: Text(
                                  staff['name'] ?? 'Staff',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  "Code: ${staff['staffcode'] ?? '-'} • ${isFw ? 'Field Worker (~50m proximity required)' : 'Office Staff'}",
                                  style: TextStyle(fontSize: 12, color: isFw ? Colors.deepPurple : Colors.black54),
                                ),
                                value: isFw,
                                activeColor: Colors.deepPurple,
                                onChanged: (val) async {
                                  final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId?.toString();
                                  if (companyId != null) {
                                    final staffId = staff['staffid'].toString();
                                    final newStatus = val ? 'Y' : 'N';
                                    setState(() {
                                      staff['fieldworker'] = newStatus;
                                    });
                                    final ok = await _api.updateFieldWorkerStatus(companyId, staffId, newStatus);
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("${staff['name']} set to ${val ? 'Field Worker' : 'Office Staff'}"),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      _loadData();
                                    } else {
                                      setState(() {
                                        staff['fieldworker'] = isFw ? 'Y' : 'N';
                                      });
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}
