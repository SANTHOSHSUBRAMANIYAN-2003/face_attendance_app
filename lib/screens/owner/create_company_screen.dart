import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/session_provider.dart';

class CreateCompanyScreen extends StatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  State<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends State<CreateCompanyScreen> {
  final _nameController = TextEditingController();
  final _staffPrefixController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();
  final _addr3Controller = TextEditingController();
  final _phoneController = TextEditingController();
  final _api = ApiService();
  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchCompanyDetails();
  }

  Future<void> _fetchCompanyDetails() async {
     final session = Provider.of<SessionProvider>(context, listen: false);
     final companyId = session.currentUser?.companyId;

     if (companyId == null) {
       setState(() => _isFetching = false);
       return;
     }
     
     if (session.currentUser?.companyName != null) {
        _nameController.text = session.currentUser!.companyName!;
     }
     
     if (session.currentUser?.staffPrefix != null) {
        _staffPrefixController.text = session.currentUser!.staffPrefix!;
     }
     
     // Pre-fill other details if saved locally
     if (session.currentUser?.address1 != null) _addr1Controller.text = session.currentUser!.address1!;
     if (session.currentUser?.address2 != null) _addr2Controller.text = session.currentUser!.address2!;
     if (session.currentUser?.address3 != null) _addr3Controller.text = session.currentUser!.address3!;
     if (session.currentUser?.phone != null) _phoneController.text = session.currentUser!.phone!;

     try {
       // Ideally fetch fresh data via API
       // Phase 1 shortcut: Use existing Session or MSSQL. 
       // Since we removed MSSQLService, we should use 'GetOwnerStats' or 'Login' data if available, 
       // but for now let's pre-fill Company Name from Session if available or empty.
       // User asked to "load that company name", which implies reading from Session/API.
       
       // Note: We don't have a "GetCompanyDetails" API yet.
       // OPTION: Reuse login logic or just rely on what we have.
       // Given constraint, I will stick to what the user explicitly asked: 
       // "make that company name only readable". 
       // I'll grab the name from previous Login API session if possible, or just leave it blank if not available.
       
       // Real app approach: Call an API to get company details.
       // For now, I will simulate fetching or just let user enter.
       // Wait, session provider might not have company name...
       // Let's check session. It doesn't have company name.
       
       // Since we removed MSSQL, we can't fetch. 
       // I will assume company name is not easily fetchable without a specific GET API for it.
       // BUT, the USER asked to load it. 
       // I will add a temporary 'getCompanyDetails' hack-ish call using 'getOwnerStats' doesn't help.
       
       // Let's implement a 'getCompanyProfile' in ApiService using the generic 'getOwnerStats' ? No.
       // I will skip fetching *existing* address for now (since no API for it) BUT I will assume the NAME is passed or stored.
       // Actually, I can use 'GetAllStaff' API to get 'location' which might be address? No.
       
       // RE-READ: "defaulty load the company name... in signup screen using that api take that company name and load it here"
       // The user implies storing it locally.
       // I will update SessionProvider to store CompanyName.
     } catch (e) {
       // ignore
     } finally {
       if (mounted) setState(() => _isFetching = false);
     }
  }

  Future<void> _saveCompanyDetails() async {
    setState(() => _isLoading = true);
    
    final session = Provider.of<SessionProvider>(context, listen: false);
    final companyId = session.currentUser?.companyId?.toString();
    final companyName = session.currentUser?.companyName ?? _nameController.text;
    final staffPrefix = session.currentUser?.staffPrefix ?? _staffPrefixController.text;

    if (companyId == null) return;

    final success = await _api.updateCompany(
      companyId: companyId,
      companyName: companyName,
      address1: _addr1Controller.text,
      address2: _addr2Controller.text,
      address3: _addr3Controller.text,
      phone: _phoneController.text,
    );

    if (mounted) {
       setState(() => _isLoading = false);
       if (success) {
          // Update Session Persistence
          await session.updateCompanyDetails(
             address1: _addr1Controller.text,
             address2: _addr2Controller.text,
             address3: _addr3Controller.text,
             phone: _phoneController.text,
             companyName: companyName,
             staffPrefix: staffPrefix,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Company Details Updated!")));
          Navigator.pop(context);
       } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update Failed")));
       }
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isReadOnly = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        readOnly: isReadOnly,
        enabled: !isReadOnly, // Disable interaction if read-only
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          filled: true,
          fillColor: isReadOnly ? Colors.grey[200] : Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isNameKnown = Provider.of<SessionProvider>(context).currentUser?.companyName != null;
    bool isPrefixKnown = Provider.of<SessionProvider>(context).currentUser?.staffPrefix != null;
    
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
                title: const Text("Company Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              Expanded(
                child: _isFetching 
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Glass Card Effect
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ],
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.business, size: 60, color: Colors.white),
                                const SizedBox(height: 20),
                                
                                
                                _buildTextField(
                                  _nameController, 
                                  "Company Name", 
                                  Icons.domain, 
                                  isReadOnly: isNameKnown
                                ),
                                _buildTextField(
                                  _staffPrefixController, 
                                  "Staff Prefix", 
                                  Icons.badge_outlined, 
                                  isReadOnly: isPrefixKnown
                                ),
                                _buildTextField(_addr1Controller, "Address 1", Icons.home),
                                _buildTextField(_addr2Controller, "Address 2", Icons.location_city),
                                _buildTextField(_addr3Controller, "Address 3", Icons.map),
                                _buildTextField(_phoneController, "Phone", Icons.phone),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: _isLoading 
                              ? const Center(child: CircularProgressIndicator(color: Colors.white))
                              : ElevatedButton(
                                  onPressed: _saveCompanyDetails,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.deepPurple,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    elevation: 5,
                                  ),
                                  child: const Text("SAVE DETAILS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                ),
                          ),
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
