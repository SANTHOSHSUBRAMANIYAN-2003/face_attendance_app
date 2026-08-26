import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/face_service.dart';
import '../../widgets/face_overlay_painter.dart';
import '../login_screen.dart';
import 'active_tracking_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with WidgetsBindingObserver {
  // Services
  final _api = ApiService();
  final _faceService = FaceService();

  // Controllers
  final _staffCodeController = TextEditingController();

  // State
  int _currentStep = 0; // 0 = Enter Code, 1 = Scan Face
  bool _isLoading = false;
  List<dynamic> _allStaffList = [];
  Map<String, dynamic>? _selectedStaff;
  String _attendanceType = "I"; // 'I' for IN, 'O' for OUT

  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isScanning = false;
  String _statusMessage = "";
  Color _statusColor = Colors.white;

  String? _staffPrefix;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      setState(() => _staffPrefix = session.currentUser?.staffPrefix);
      precacheImage(
        const NetworkImage(
          "https://i.pinimg.com/originals/12/e8/a6/12e8a6a547e317524121f7a5d6084036.gif",
        ),
        context,
      );
    });
    _fetchStaffList();
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App backgrounded or paused -> release camera resources
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (cameraController != null && cameraController.value.isInitialized) {
        setState(() => _isCameraReady = false);
        cameraController.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App resumed from recents -> re-initialize camera safely
      _initCamera();
    }
  }

  Future<void> _fetchStaffList() async {
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;
    if (companyId != null) {
      final list = await _api.getAllStaff(companyId.toString());
      if (mounted) {
        setState(() => _allStaffList = list);
      }
    }
  }

  Future<void> _initCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

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
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      print("Camera init error: $e");
    }
  }

  // KEYPAD LOGIC
  void _onKeyTap(String value) {
    if (value == "CLEAR") {
      _staffCodeController.clear();
    } else if (value == "BACK") {
      if (_staffCodeController.text.isNotEmpty) {
        _staffCodeController.text = _staffCodeController.text.substring(
          0,
          _staffCodeController.text.length - 1,
        );
      }
    } else {
      if (_staffCodeController.text.length < 10) {
        // Limit length
        _staffCodeController.text += value;
      }
    }
  }

  // Step 1 Logic: Validate Code
  Future<void> _validateAndProceed() async {
    final enteredCode = _staffCodeController.text.trim();
    if (enteredCode.isEmpty) {
      _showMessage("Enter Staff Code", Colors.orangeAccent);
      return;
    }

    // Prepend Prefix if exists
    final fullCode = (_staffPrefix != null)
        ? "$_staffPrefix$enteredCode"
        : enteredCode;

    if (_allStaffList.isEmpty) {
      _fetchStaffList();
      _showMessage("Syncing Staff List... Try again.", Colors.blueAccent);
      return;
    }

    // Check if code exists in list
    // Priority 1: Check with Prefix (e.g. ABC100)
    // Priority 2: Check raw code (e.g. 100 - legacy data)
    final match = _allStaffList.firstWhere((s) {
      final sCode = s['staffcode'].toString().trim().toLowerCase();
      return sCode == fullCode.trim().toLowerCase();
    }, orElse: () => null);

    if (match != null) {
      // -------------------------------------------------------
      // SUBSCRIPTION EXPIRY CHECK
      // -------------------------------------------------------
      final subdateStr = match['subdate']?.toString() ?? '';
      if (subdateStr.isNotEmpty) {
        final subdate = DateTime.tryParse(subdateStr);
        if (subdate != null && DateTime.now().isAfter(subdate)) {
          // Subscription expired — check wallet balance for self-renewal
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );

          final companyId = Provider.of<SessionProvider>(context, listen: false).currentUser?.companyId.toString() ?? "";
          final staffId = match['staffid']?.toString() ?? "";
          double balance = 0.0;
          
          if (companyId.isNotEmpty) {
            balance = await _api.walletBalance(companyId) ?? 0.0;
          }

          if (mounted) Navigator.pop(context); // close loader

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              bool isRenewing = false;
              return StatefulBuilder(
                builder: (context, setStateDialog) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                        SizedBox(width: 8),
                        Expanded(child: Text("Subscription Expired", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [


                        Text(


                          "Your account expired on ${subdateStr.split(' ')[0]}.\n",
                          style: const TextStyle(fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              const Text("Company Wallet Balance", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text("Rs. ${balance.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (balance >= 50)
                          const Text("You can renew your account now for Rs. 50.", style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold))
                        else
                          const Text("Insufficient wallet balance. Please contact your administrator to renew.For contact +91 9942523247", style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: isRenewing ? null : () {
                          Navigator.pop(ctx);
                          _reset();
                        },
                        child: Text(balance >= 50 ? "Cancel" : "OK", style: const TextStyle(color: Colors.grey)),
                      ),
                      if (balance >= 50)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: isRenewing ? null : () async {
                            setStateDialog(() => isRenewing = true);
                            

                            bool debitSuccess = await _api.walletDebit(companyId: companyId, staffId: staffId, amount: 50);
                            if (debitSuccess) {

                              bool renewSuccess = await _api.renewSubscription(staffId, companyId);
                              if (renewSuccess) {
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Renewed Successfully!"), backgroundColor: Colors.green));

                                  _fetchStaffList();
                                  _reset();
                                }
                                return;
                              }
                            }

                            setStateDialog(() => isRenewing = false);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Renewal Failed. Try again."), backgroundColor: Colors.red));
                          },
                          child: isRenewing 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Renew Now (Rs.50)"),
                        ),
                    ],
                  );
                }
              );
            },
          );
          return; // Block further processing
        }
      }
      // -------------------------------------------------------

      setState(() {
        _selectedStaff = match; // Store basic info
        _currentStep = 1; // Move to Camera
        _statusMessage = "Ready for $_attendanceType: ${match['name']}";
        _statusColor = Colors.white;
      });
      // AUTO-SCAN TRIGGER: Wait 1.5s for camera to settle, then start verification
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _currentStep == 1 && !_isScanning) {
          _verifyFace();
        }
      });
    } else {
      _showMessage(
        "Invalid Staff Code: $fullCode (or $enteredCode)",
        Colors.redAccent,
      );
    }
  }

  void _startTrackingWithoutFaceScan() {
    final enteredCode = _staffCodeController.text.trim();
    if (enteredCode.isEmpty) {
      _showMessage("Enter Staff Code", Colors.orangeAccent);
      return;
    }

    final fullCode = (_staffPrefix != null)
        ? "$_staffPrefix$enteredCode"
        : enteredCode;

    if (_allStaffList.isEmpty) {
      _fetchStaffList();
      _showMessage("Syncing Staff List... Try again.", Colors.blueAccent);
      return;
    }

    final match = _allStaffList.firstWhere((s) {
      final sCode = s['staffcode'].toString().trim().toLowerCase();
      return sCode == fullCode.trim().toLowerCase();
    }, orElse: () => null);

    if (match != null) {
      // Check if Owner has enabled tracking for this staff
      final isActive =
          match['is_tracking_active'] == '1' ||
          match['is_tracking_active'] == 1 ||
          match['is_tracking_active'] == true;

      if (!isActive) {
        _showMessage(
          "Tracking locked. Ask Owner to enable.",
          Colors.orangeAccent,
        );
        return;
      }

      // Navigate to Active Tracking Screen immediately
      // Don't pop, push on top so they can return later if they want
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveTrackingScreen(staffDetails: match),
        ),
      );
    } else {
      _showMessage(
        "Invalid Staff Code: $fullCode (or $enteredCode)",
        Colors.redAccent,
      );
    }
  }

  // Step 2 Logic: Verify Face
  Future<void> _verifyFace() async {
    if (!_isCameraReady || _isScanning || _selectedStaff == null) return;

    setState(() {
      _isScanning = true;
      _statusMessage = "Verifying...";
      _statusColor = Colors.blueAccent;
    });

    try {
      // 1. Get Full Details
      final companyId = Provider.of<SessionProvider>(
        context,
        listen: false,
      ).currentUser?.companyId;
      final fullStaffDetails = await _api.getStaffDetails(
        _selectedStaff!['staffcode'].toString(),
        companyId.toString(),
      );

      if (fullStaffDetails == null || fullStaffDetails['encoding'] == null) {
        _showMessage("Face Data Not Found", Colors.redAccent);
        _isScanning = false;
        return;
      }

      // 2. Capture
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final currentEmbedding = await _faceService.getFaceEmbedding(bytes);

      if (currentEmbedding == null) {
        _showMessage("No Face Detected", Colors.redAccent);
        _isScanning = false;
        return;
      }

      // 3. Compare
      String hexString = fullStaffDetails['encoding'];
      List<double> registeredEmbedding = _parseHexEmbedding(hexString);
      double dist = _faceService.euclideanDistance(
        currentEmbedding,
        registeredEmbedding,
      );

      if (dist <0.75) {
        await _markAttendance(fullStaffDetails);
      } else {
        _showMessage(
          "Face Mismatch (Score: ${dist.toStringAsFixed(2)})",
          Colors.red,
        );
        setState(
          () => _isScanning = false,
        ); // Reset so the next auto-call can proceed
        // If mismatch, wait 2s and try again automatically
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && _currentStep == 1) {
          _verifyFace();
        }
      }
    } catch (e) {
      _showMessage("Error: $e", Colors.red);
      setState(() => _isScanning = false);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _currentStep == 1) _verifyFace();
    } finally {
      // Done
    }
  }

  List<double> _parseHexEmbedding(String hexString) {
    if (hexString.startsWith("0x")) hexString = hexString.substring(2);
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      String byteStr = hexString.substring(i, i + 2);
      bytes.add(int.parse(byteStr, radix: 16));
    }
    final uint8List = Uint8List.fromList(bytes);
    final buffer = uint8List.buffer;
    final floatList = Float32List.view(buffer);
    return floatList.toList();
  }

  /// Google Play: Prominent Disclosure dialog for location access
  Future<bool> _showLocationDisclosure() async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(child: Text("Location Access")),
          ],
        ),
        content: const Text(
          "This app collects your GPS location while marking attendance to verify that you are within the work premises.\n\n"
          "• Location is only captured at the moment of attendance.\n"
          "• It is visible only to your company administrator.\n"
          "• It is not shared with any third parties.",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text("I Agree"),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  Future<void> _markAttendance(Map<String, dynamic> staff) async {
    final staffId = staff['staffid'].toString();
    final companyId = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).currentUser?.companyId;

    _showMessage("Fetching Location...", Colors.orangeAccent);

    String? latStr;
    String? longStr;
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage("Location Services Disabled", Colors.redAccent);
      } else {
        // Show Prominent Disclosure once per install (Google Play requirement)
        final prefs = await SharedPreferences.getInstance();
        final disclosureShown =
            prefs.getBool('attendance_disclosure_shown') ?? false;
        if (!disclosureShown) {
          final agreed = await _showLocationDisclosure();
          if (!agreed) {
            _showMessage(
              "Location permission is required for attendance.",
              Colors.redAccent,
            );
            return;
          }
          await prefs.setBool('attendance_disclosure_shown', true);
        }

        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          );
          latStr = position.latitude.toString();
          longStr = position.longitude.toString();
        }
      }
    } catch (e) {
      print("Location error: $e");
    }

    _showMessage("Saving Attendance...", Colors.blueAccent);

    final res = await _api.markAttendanceWithResult(
      staffId,
      companyId.toString(),
      _attendanceType,
      lat: latStr,
      long: longStr,
    );

    if (res['status'] == 'success') {
      _showMessage(res['message'] ?? "Success! Checked $_attendanceType.", Colors.green);

      // Auto-start live tracking pings for field worker so geofence breaches are tracked & sent
      if (latStr != null && latStr.isNotEmpty && longStr != null && longStr.isNotEmpty) {
        try {
          await _api.toggleTracking(staffId, companyId.toString(), 'START');
          await _api.updateLiveLocation(staffId, companyId.toString(), latStr, longStr);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('tracking_staff_id', staffId);
          await prefs.setString('tracking_company_id', companyId.toString());
          await prefs.setBool('is_tracking_active', true);

          // Trigger FlutterBackgroundService to wake up and start ping timer immediately
          final bgService = FlutterBackgroundService();
          if (!await bgService.isRunning()) {
            await bgService.startService();
          }
          print("DEBUG: Active location tracking service started for staffId $staffId");
        } catch (e) {
          print("DEBUG: Error starting background tracking: $e");
        }
      }

      await Future.delayed(const Duration(seconds: 2));
      _reset();
    } else {
      final errorMsg = res['message'] ?? (_attendanceType == "I"
          ? "Already Checked IN"
          : "Already Checked OUT");
      _showMessage(errorMsg, Colors.orangeAccent);
      await Future.delayed(const Duration(seconds: 3));
      _reset();
    }
  }

  void _reset() {
    if (mounted) {
      setState(() {
        _currentStep = 0;
        _isScanning = false;
        _staffCodeController.clear();
        _selectedStaff = null;
        _statusMessage = "";
        // Keep previous type or reset? Usually keep, maybe shift change needs manual switch
      });
    }
  }

  void _showMessage(String msg, Color color) {
    if (mounted) {
      setState(() {
        _statusMessage = msg;
        _statusColor = color;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _staffCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _currentStep == 0
        ? _buildStep1_CodeEntry()
        : _buildStep2_FaceVerify();
  }

  // --- UI Step 1: Code Entry ---
  // --- UI Step 1: Code Entry ---
  Widget _buildStep1_CodeEntry() {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
            ),
          ),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Face Attendance",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        onPressed: () {
                          Provider.of<SessionProvider>(
                            context,
                            listen: false,
                          ).logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Top Content (Flexible)
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Text(
                        "Welcome Back!",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Enter Staff Code",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Toggle
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTypeButton("CHECK IN", "I"),
                            _buildTypeButton("CHECK OUT", "O"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Code Display (Text Box)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _staffCodeController,
                          readOnly: true, // Keypad only
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            hintText: "Enter Code",
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixText: _staffPrefix,
                            prefixStyle: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                // Keypad (Flexible but larger)
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildKeyRow(["1", "2", "3"]),
                          const SizedBox(height: 10),
                          _buildKeyRow(["4", "5", "6"]),
                          const SizedBox(height: 10),
                          _buildKeyRow(["7", "8", "9"]),
                          const SizedBox(height: 10),
                          _buildKeyRow(["CLEAR", "0", "BACK"]),
                          const SizedBox(height: 15),

                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _validateAndProceed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF764BA2),
                                      foregroundColor: Colors.white,
                                      elevation: 5,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      "VERIFY\nIDENTITY",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _startTrackingWithoutFaceScan,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo,
                                      foregroundColor: Colors.white,
                                      elevation: 5,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      "LIVE\nTRACKING",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value) {
    bool isSelected = _attendanceType == value;
    return GestureDetector(
      onTap: () => setState(() => _attendanceType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ), // Reduced Padding
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF667EEA) : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13, // Reduced font
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String value) {
    return GestureDetector(
      onTap: () => _onKeyTap(value),
      child: Container(
        width: 60, // Reduced size
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade50,
        ),
        child: value == "BACK"
            ? const Icon(
                Icons.backspace_rounded,
                color: Colors.black54,
                size: 22,
              )
            : value == "CLEAR"
            ? const Text(
                "C",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              )
            : Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }

  // --- UI Step 2: Full Screen Camera ---
  Widget _buildStep2_FaceVerify() {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full Screen Camera
          if (_isCameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            const Center(child: CircularProgressIndicator()),

          // Face Guide Overlay
          CustomPaint(painter: FaceOverlayPainter(), child: Container()),

          // Scanning GIF Overlay (Neater Framing)
          Center(
            child: ClipOval(
              child: Opacity(
                opacity: 0.6,
                child: Image.network(
                  "https://i.pinimg.com/originals/12/e8/a6/12e8a6a547e317524121f7a5d6084036.gif",
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.65,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => setState(() {
                          _currentStep = 0;
                          _statusMessage = "";
                        }),
                      ),
                      Column(
                        children: [
                          Text(
                            _attendanceType == "I"
                                ? "CHECKING IN"
                                : "CHECKING OUT",
                            style: TextStyle(
                              color: _attendanceType == "I"
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(blurRadius: 5, color: Colors.black),
                              ],
                            ),
                          ),
                          Text(
                            _selectedStaff?['name'] ?? "Staff",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 10, color: Colors.black),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40), // Balance
                    ],
                  ),
                ),

                const Spacer(),

                // Instructions
                const Text(
                  "Align Face within the Frame",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 20),

                // Bottom Control
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(blurRadius: 10, color: Colors.black),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isScanning ? null : _verifyFace,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isScanning ? Colors.grey : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.deepPurple,
                              width: 4,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10),
                            ],
                          ),
                          child: Icon(
                            _isScanning ? Icons.hourglass_empty : Icons.camera,
                            size: 40,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Tap to Verify",
                        style: TextStyle(
                          color: Colors.white70,
                          shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                        ),
                      ),
                    ],
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
