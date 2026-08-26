import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/face_service.dart';
import '../../widgets/face_overlay_painter.dart';

class StaffRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? staffToEdit;
  const StaffRegistrationScreen({super.key, this.staffToEdit});

  @override
  State<StaffRegistrationScreen> createState() => _StaffRegistrationScreenState();
}

class _StaffRegistrationScreenState extends State<StaffRegistrationScreen> {
  // Text Controllers
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();
  final _addr3Controller = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _dorController = TextEditingController();

  final _faceService = FaceService();
  
  CameraController? _cameraController;
  List<double>? _currentEmbedding;
  bool _isCameraReady = false;
  bool _isLoading = false;
  bool _isCameraOpen = false; 

  String? _staffPrefix;
  bool _isFieldWorker = false;

  @override
  void initState() {
    super.initState();
    // Get Prefix
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      setState(() {
        _staffPrefix = session.currentUser?.staffPrefix;
        print("DEBUG: Loaded Staff Prefix: '$_staffPrefix'"); // Debug
      });
      
      if (widget.staffToEdit != null) {
        String fullCode = (widget.staffToEdit!['staffcode'] ?? "").toString();
        // If prefix exists and code starts with it, strip it for editing
        if (_staffPrefix != null && fullCode.startsWith(_staffPrefix!)) {
           _codeController.text = fullCode.substring(_staffPrefix!.length);
        } else {
           _codeController.text = fullCode;
        }

        _nameController.text = (widget.staffToEdit!['name'] ?? "").toString();
        _phoneController.text = (widget.staffToEdit!['phone'] ?? "").toString();
        _addr1Controller.text = (widget.staffToEdit!['address1'] ?? "").toString();
        _addr2Controller.text = (widget.staffToEdit!['address2'] ?? "").toString();
        _addr3Controller.text = (widget.staffToEdit!['address3'] ?? "").toString();
        
        String fw = (widget.staffToEdit!['fieldworker'] ?? "N").toString();
        _isFieldWorker = (fw.toUpperCase() == "Y");

        String dobObj = (widget.staffToEdit!['dob'] ?? "").toString();
        if(dobObj.isNotEmpty) _dobController.text = dobObj.split('T')[0];

        String dorObj = (widget.staffToEdit!['dor'] ?? "").toString();
        if(dorObj.isNotEmpty) _dorController.text = dorObj.split('T')[0];
      }
    });
  }

  Future<void> _saveStaff() async {
    final isUpdate = widget.staffToEdit != null;
    
    if (!isUpdate && _currentEmbedding == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please capture face first")));
      return;
    }
    
    setState(() => _isLoading = true);
    final session = Provider.of<SessionProvider>(context, listen: false);
    final companyId = (session.currentUser?.companyId ?? 0).toString();
    
    // Construct Full Code
    String fullStaffCode = _codeController.text;
    if (_staffPrefix != null && !fullStaffCode.startsWith(_staffPrefix!)) {
       fullStaffCode = "$_staffPrefix$fullStaffCode";
    }

    try {
      final api = ApiService();

      // CHECK IF STAFF CODE ALREADY EXISTS (Only for New Registrations)
      if (!isUpdate) {
        final allStaff = await api.getAllStaff(companyId);
        final exists = allStaff.any((s) => s['staffcode'].toString().toLowerCase() == fullStaffCode.toLowerCase());
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Staff Code '$fullStaffCode' already exists! Please use a different code.")),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // CHECK WALLET BALANCE before registering new staff (needs Rs.50)
        final balance = await api.walletBalance(companyId);
        if (balance == null || balance < 50.0) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Insufficient Balance"),
                  ],
                ),
                content: Text(
                  "Current balance: Rs.${(balance ?? 0).toStringAsFixed(2)}\n\n"
                  "Adding a staff requires Rs.50 (valid for 1 year).\n"
                  "Please top up your wallet to continue.",
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      String? hexString;
      if (_currentEmbedding != null) {
         final floatBytes = Float32List.fromList(_currentEmbedding!);
         final byteBuffer = floatBytes.buffer.asUint8List();
         hexString = "0x${byteBuffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}";
      }
      
      if (isUpdate) {
         // UPDATE — no wallet/subdate changes for updates
         final staffId = widget.staffToEdit!['staffid'].toString();
         final success = await api.updateStaff(
            staffId: staffId, 
            companyId: companyId,
            name: _nameController.text,
            phone: _phoneController.text,
            address1: _addr1Controller.text,
            address2: _addr2Controller.text,
            address3: _addr3Controller.text,
            dob: _dobController.text,
            dor: _dorController.text,
            encodingHex: hexString,
         );
         await api.updateFieldWorkerStatus(companyId, staffId, _isFieldWorker ? "Y" : "N");

         if (mounted) {
           if (success) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Staff Updated Successfully!")));
              Navigator.pop(context, true);
           } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update Failed. Check API.")));
           }
         }
      } else {
         // REGISTER NEW STAFF — returns new staffId
         final newStaffId = await api.registerStaff(
            staffCode: fullStaffCode, 
            companyId: companyId,
            name: _nameController.text,
            address1: _addr1Controller.text,
            address2: _addr2Controller.text,
            address3: _addr3Controller.text,
            phone: _phoneController.text,
            encodingHex: hexString!,
            dob: _dobController.text,
            dor: _dorController.text,
            fieldWorker: _isFieldWorker ? "Y" : "N",
         );

         if (newStaffId != null && newStaffId.isNotEmpty) {
           // Debit Rs.50 from wallet for this staff
           await api.walletDebit(
             companyId: companyId,
             amount: 50.0,
             staffId: newStaffId,
           );
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text("Staff Registered! Rs.50 deducted. Subscription valid for 1 year."),
                 backgroundColor: Colors.green,
               ),
             );
             Navigator.pop(context, true);
           }
         } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Failed. Check API.")));
           }
         }
      }

    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resignStaff() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: "SELECT DATE OF RELIEVING",
    );

    if (picked == null) return;

    final dorStr = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Resignation"),
        content: Text("Are you sure you want to mark this employee as resigned?\n\nDate of Relieving: $dorStr"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("CONFIRM", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final companyId = (session.currentUser?.companyId ?? 0).toString();
      final api = ApiService();

      final success = await api.updateStaff(
        staffId: widget.staffToEdit!['staffid'].toString(),
        companyId: companyId,
        active: 'N',
        dor: dorStr,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Staff Resigned Successfully!"), backgroundColor: Colors.orange),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action Failed. Check API.")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isDate = false, bool isReadOnly = false, String? prefixText}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        readOnly: isDate || isReadOnly,
        onTap: isDate && !isReadOnly ? () => _selectDate(controller) : null,
        keyboardType: (label == "Staff Code" || label == "Phone") ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText, 
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          filled: true,
          fillColor: isReadOnly ? Colors.grey[200] : Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium, 
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) {
       setState(() {
          _isCameraReady = true;
          _isCameraOpen = true;
       });
    }
  }

  Future<void> _captureFace() async {
    if (!_isCameraReady || _cameraController == null) return;
    
    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      
      setState(() {
         _isCameraReady = false; 
      });
      _cameraController?.dispose();

      _showUseOrRetryDialog(bytes);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Capture Error: $e")));
    }
  }

  Future<void> _processFace(Uint8List bytes) async {
     final embedding = await _faceService.getFaceEmbedding(bytes);
     if (embedding != null) {
       setState(() {
         _currentEmbedding = embedding;
         _isCameraOpen = false; 
       });
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Face Encoded Successfully!")));
     } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Face Detected. Please Retry.")));
       setState(() => _isCameraOpen = false);
     }
  }

  void _showUseOrRetryDialog(Uint8List imageBytes) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Use this photo?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Image.memory(imageBytes, height: 200, fit: BoxFit.cover),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openCamera(); 
              },
              child: const Text("Retry"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _processFace(imageBytes);
              },
              child: const Text("Use"),
            ),
          ],
        ),
      );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}";
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _addr1Controller.dispose();
    _addr2Controller.dispose();
    _addr3Controller.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _dorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraOpen) {
      return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
               if (_isCameraReady && _cameraController != null)
                  CameraPreview(_cameraController!)
               else
                  const Center(child: CircularProgressIndicator()),
               
               CustomPaint(
                 painter: FaceOverlayPainter(),
                 child: Container(),
               ),
               
               SafeArea(
                 child: Column(
                   children: [
                       Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                               IconButton(
                                 icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                                 onPressed: () => setState(() {
                                    _isCameraOpen = false;
                                    _isCameraReady = false;
                                    _cameraController?.dispose();
                                 }),
                               )
                            ],
                         ),
                       ),
                       const Spacer(),
                       
                       const Text(
                          "Align Face within the Frame",
                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold,  shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
                       ),
                       const SizedBox(height: 20),
                       GestureDetector(
                           onTap: _captureFace,
                           child: Container(
                             margin: const EdgeInsets.only(bottom: 50),
                             width: 80,
                             height: 80,
                             decoration: BoxDecoration(
                               color: Colors.white,
                               shape: BoxShape.circle,
                               border: Border.all(color: Colors.deepPurple, width: 4),
                               boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
                             ),
                             child: const Icon(Icons.camera, size: 40, color: Colors.deepPurple),
                           ),
                       )
                   ],
                 ),
               )
            ],
          ),
       );
    }

    final isUpdate = widget.staffToEdit != null;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text(isUpdate ? "Update Staff" : "Register Staff", style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                actions: [
                  if (isUpdate)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      tooltip: "Delete Employee / Mark Resigned",
                      onPressed: _isLoading ? null : _resignStaff,
                    ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                         ElevatedButton.icon(
                             onPressed: _openCamera,
                             icon: const Icon(Icons.camera_alt),
                             label: Text(_currentEmbedding == null ? (isUpdate ? "Update Face (Optional)" : "Open Camera & Capture Face") : "Retake Photo"),
                             style: ElevatedButton.styleFrom(
                                backgroundColor: _currentEmbedding != null ? Colors.green : Colors.white,
                                foregroundColor: _currentEmbedding != null ? Colors.white : Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                             ),
                           ),
                         
                         const SizedBox(height: 20),
                         if (_currentEmbedding != null)
                            Container(
                               padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                               decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.greenAccent)),
                               child: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: const [Icon(Icons.check_circle, color: Colors.greenAccent), SizedBox(width: 8), Text("Photo Captured & Encoded", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
                               ),
                            ),
                         
                         const SizedBox(height: 30),

                         _buildTextField(_codeController, "Staff Code", Icons.qr_code, isReadOnly: isUpdate, prefixText: _staffPrefix),
                         _buildTextField(_nameController, "Full Name", Icons.person),
                         
                         _buildTextField(_addr1Controller, "Address 1", Icons.home),
                         _buildTextField(_addr2Controller, "Address 2", Icons.location_city),
                         _buildTextField(_addr3Controller, "Address 3", Icons.map),
                         _buildTextField(_phoneController, "Phone", Icons.phone),
                         _buildTextField(_dobController, "Date of Birth", Icons.calendar_today, isDate: true),
                         _buildTextField(_dorController, "Date of Registration", Icons.event_note, isDate: true),

                         const SizedBox(height: 30),
                         SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                               onPressed: _isLoading ? null : _saveStaff,
                               style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                               ),
                               child: _isLoading 
                                 ? const CircularProgressIndicator(color: Colors.white)
                                 : Text(isUpdate ? "UPDATE STAFF" : "REGISTER STAFF", style: const TextStyle(fontSize: 16)),
                            ),
                         )
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
}
