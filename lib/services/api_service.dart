import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ApiService {
  static const String baseUrl = "https://www.bneedsbill.com/payrollapi";

  Future<Map<String, dynamic>?> login(String username, String password) async {
    final url = Uri.parse(
      "$baseUrl/LoginApi.aspx?username=$username&password=$password",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("Login Error: $e");
    }
    return null;
  }

  // Register staff — returns the new staffId string on success, null on failure
  Future<String?> registerStaff({
    required String staffCode,
    required String companyId,
    required String name,
    required String address1,
    required String address2,
    required String address3,
    required String phone,
    required String encodingHex,
    required String dob,
    required String dor,
    String fieldWorker = "N",
  }) async {
    final url = Uri.parse("$baseUrl/RegisterStaffApi.aspx");
    // Subscription end date: today + 1 year
    final subdate = DateTime.now().add(const Duration(days: 365));
    final subdateStr = "${subdate.year}-${subdate.month.toString().padLeft(2,'0')}-${subdate.day.toString().padLeft(2,'0')}";

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "staffcode": staffCode,
          "companyid": companyId,
          "name": name,
          "address1": address1,
          "address2": address2,
          "address3": address3,
          "phone": phone,
          "encoding": encodingHex,
          "doj": DateTime.now().toIso8601String(),
          "dob": dob,
          "dor": dor,
          "subdate": subdateStr,
          "fieldworker": fieldWorker,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data.first['status'] == 'success') {
          return data.first['staffid']?.toString(); // Return new staffId
        }
      }
    } catch (e) {
      print("Register Error: $e");
    }
    return null;
  }

  // Changed to GET for better reliability
  Future<Map<String, dynamic>?> getStaffDetails(
    String staffCode,
    String companyId,
  ) async {
    final url = Uri.parse(
      "$baseUrl/GetStaffDetailsApi.aspx?staffcode=$staffCode&companyid=$companyId",
    );
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0].containsKey('staffid')) {
          return data.first as Map<String, dynamic>;
        } else {
          print("GetStaffDetails Fail: ${response.body}"); // Debug
        }
      } else {
        print("GetStaffDetails HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("GetStaffDetails Error: $e");
    }
    return null;
  }

  // Changed to return Map with status and message
  Future<Map<String, dynamic>> markAttendanceWithResult(
    String staffId,
    String companyId,
    String type, {
    String? date,
    String? time,
    String? lat,
    String? long,
  }) async {
    final url = Uri.parse("$baseUrl/MarkAttendanceApi.aspx");
    try {
      final body = {
        "staffid": staffId,
        "companyid": companyId,
        "type": type, // 'I' or 'O' or 'D', 'V', 'R', 'A'
      };

      if (date != null) body["attdate"] = date;
      if (lat != null) body["lat"] = lat;
      if (long != null) body["long"] = long;

      if (time != null) {
        body["atttime"] = time;
      } else {
        body["atttime"] = DateFormat('HH:mm:ss').format(DateTime.now());
      }

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return Map<String, dynamic>.from(data.first);
        }
      }
    } catch (e) {
      print("MarkAttendance Error: $e");
    }
    return {"status": "fail", "message": "Network error or invalid server response"};
  }

  Future<bool> markAttendance(
    String staffId,
    String companyId,
    String type, {
    String? date,
    String? time,
    String? lat,
    String? long,
  }) async {
    final res = await markAttendanceWithResult(staffId, companyId, type, date: date, time: time, lat: lat, long: long);
    return res['status'] == 'success';
  }

  // Changed to GET for better reliability
  Future<Map<String, dynamic>?> getOwnerStats(String companyId) async {
    final url = Uri.parse(
      "$baseUrl/GetOwnerStatsApi.aspx?companyid=$companyId",
    );
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data.first['status'] == 'success') {
          return data.first as Map<String, dynamic>;
        } else {
          print("GetOwnerStats Fail: ${response.body}");
        }
      }
    } catch (e) {
      print("GetOwnerStats Error: $e");
    }
    return null;
  }

  // Changed to GET for better reliability
  Future<List<dynamic>> getAllStaff(String companyId) async {
    final url = Uri.parse("$baseUrl/GetAllStaffApi.aspx?companyid=$companyId");
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("GetAllStaff Error: $e");
    }
    return [];
  }

  // SignUp: returns the new companyId on success, null on failure
  Future<int?> signUp({
    required String companyName,
    required String username,
    required String password,
    required String staffPrefix,
    String phone = '',
  }) async {
    final url = Uri.parse(
      "https://www.bneedsbill.com/payrollapi/companyApi.aspx?action=I",
    );

    try {
      final payload = {
        "companyint": [
          {
            "companyname": companyName,
            "username": username,
            "password": password,
            "staffprefix": staffPrefix,
            "phone": phone,
          },
        ],
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Server returns: {"status":"success","Companyid":"123",...}
        if (data is Map && data['status'] == 'success') {
          final cid = int.tryParse(data['Companyid']?.toString() ?? '');
          return cid;
        }
      }
    } catch (e) {
      print("SignUp Error: $e");
    }
    return null;
  }

  // Update Company
  Future<bool> updateCompany({
    required String companyId,
    required String companyName,
    required String address1,
    required String address2,
    required String address3,
    required String phone,
  }) async {
    final url = Uri.parse("$baseUrl/companyApi.aspx?action=U");

    try {
      final payload = {
        "companyUp": [
          {
            "companyname": companyName,
            "address1": address1,
            "address2": address2,
            "address3": address3,
            "phone": phone,
            "companyid": companyId,
          },
        ],
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        // API returns boolean or string success? User didn't specify return format.
        // Assuming success if 200 based on previous SignUp pattern.
        return true;
      }
    } catch (e) {
      print("Error updating company: $e");
    }
    return false;
  }

  // Get Attendance Report
  Future<List<dynamic>> getAttendanceReport(
    String companyId,
    String fromDate,
    String toDate,
  ) async {
    final url = Uri.parse(
      "$baseUrl/GetAttendanceReportApi.aspx?action=GET_REPORT&companyid=$companyId&fromdate=$fromDate&todate=$toDate",
    );
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("GetAttendanceReport Error: $e");
    }
    return [];
  }

  // Shift Management APIs

  Future<bool> createShift(
    String shiftName,
    String shiftStart,
    String shiftEnd,
    String companyId,
  ) async {
    final url = Uri.parse("$baseUrl/CreateShiftApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "shiftname": shiftName,
          "shiftstart": shiftStart,
          "shiftendtime": shiftEnd,
          "companyid": companyId,
        },
      );

      if (response.statusCode == 200) {
        // Assuming API returns success status
        return true;
      }
    } catch (e) {
      print("CreateShift Error: $e");
    }
    return false;
  }

  Future<List<dynamic>> getShifts(String companyId) async {
    final url = Uri.parse("$baseUrl/GetShiftsApi.aspx?companyid=$companyId");
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("GetShifts Error: $e");
    }
    return [];
  }

  Future<bool> assignStaffToShift(
    String staffId,
    String shiftId,
    String companyId,
  ) async {
    final url = Uri.parse("$baseUrl/AssignStaffShiftApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"staffid": staffId, "shiftid": shiftId, "companyid": companyId},
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print("AssignStaffShift Error: $e");
    }
    return false;
  }

  // Holiday Management APIs

  Future<bool> manageHoliday(
    String date,
    String companyId,
    String action,
  ) async {
    final url = Uri.parse("$baseUrl/ManageHolidayApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "holidaydate": date,
          "companyid": companyId,
          "action": action, // ADD or DELETE
        },
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print("ManageHoliday Error: $e");
    }
    return false;
  }

  Future<bool> manageHolidaysBatch(
    List<String> dates,
    String companyId,
    String action,
  ) async {
    final url = Uri.parse("$baseUrl/ManageHolidayApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "holidaydates": dates,
          "companyid": companyId,
          "action": action,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print("ManageHolidaysBatch Error: $e");
    }
    return false;
  }

  Future<List<String>> getHolidays(String companyId) async {
    final url = Uri.parse("$baseUrl/GetHolidaysApi.aspx?companyid=$companyId");
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<String>((e) => e['holidaydate'].toString()).toList();
      }
    } catch (e) {
      print("GetHolidays Error: $e");
    }
    return [];
  }

  Future<bool> updateStaff({
    required String staffId,
    required String companyId,
    String? name,
    String? phone,
    String? address1,
    String? address2,
    String? address3,
    String? dob,
    String? dor,
    String? active,
    String? encodingHex,
    String? shiftId,
  }) async {
    final url = Uri.parse("$baseUrl/UpdateStaffApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "staffid": staffId,
          "companyid": companyId,
          if (name != null) "name": name,
          if (phone != null) "phone": phone,
          if (address1 != null) "address1": address1,
          if (address2 != null) "address2": address2,
          if (address3 != null) "address3": address3,
          if (dob != null) "dob": dob,
          if (dor != null) "dor": dor,
          if (active != null) "active": active,
          if (encodingHex != null) "encoding": encodingHex,
          if (shiftId != null) "shiftid": shiftId,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("UpdateStaff Error: $e");
    }
    return false;
  }

  Future<bool> createStaffLogin({
    required String username,
    required String password,
    required String companyId,
  }) async {
    final url = Uri.parse("$baseUrl/CreateStaffLoginApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": username,
          "password": password,
          "companyid": companyId,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("CreateStaffLogin Error: $e");
    }
    return false;
  }

  // Feature 2: Tracking APIs
  Future<bool> toggleTracking(
    String staffId,
    String companyId,
    String action,
  ) async {
    final url = Uri.parse("$baseUrl/ToggleTrackingApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"staffid": staffId, "companyid": companyId, "action": action},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("ToggleTracking Error: $e");
    }
    return false;
  }

  Future<bool> updateLiveLocation(
    String staffId,
    String companyId,
    String lat,
    String long,
  ) async {
    final url = Uri.parse("$baseUrl/UpdateLiveLocationApi.aspx");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "staffid": staffId,
          "companyid": companyId,
          "lat": lat,
          "long": long,
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("UpdateLiveLocation Error: $e");
    }
    return false;
  }

  Future<Map<String, dynamic>?> getLatestLiveLocation(
    String staffId,
    String companyId,
  ) async {
    final url = Uri.parse(
      "$baseUrl/GetLatestLiveLocationApi.aspx?staffid=$staffId&companyid=$companyId",
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data.first['status'] == 'success') {
          return data.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print("GetLatestLiveLocation Error: $e");
    }
    return null;
  }

  Future<List<dynamic>> getAllActiveTrackingLocations(String companyId) async {
    final url = Uri.parse(
      "$baseUrl/GetAllActiveTrackingLocationsApi.aspx?companyid=$companyId",
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty &&
            data.first is Map &&
            data.first.containsKey('status') &&
            data.first['status'] == 'fail') {
          return [];
        }
        return data;
      }
    } catch (e) {
      print("GetAllActiveTrackingLocations Error: $e");
    }
    return [];
  }

  // -------------------------------------------------------
  // WALLET / SUBSCRIPTION APIS
  // -------------------------------------------------------

  /// Credit the wallet (e.g. signup bonus)
  Future<bool> walletCredit({
    required String companyId,
    required double amount,
    String? staffId,
  }) async {
    final url = Uri.parse("$baseUrl/WalletApi.aspx");
    try {
      final body = <String, String>{
        "action": "CR",
        "companyid": companyId,
        "amount": amount.toString(),
      };
      if (staffId != null) body["staffid"] = staffId;
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("WalletCredit Error: $e");
    }
    return false;
  }

  /// Debit the wallet (e.g. staff registration fee)
  Future<bool> walletDebit({
    required String companyId,
    required double amount,
    String? staffId,
  }) async {
    final url = Uri.parse("$baseUrl/WalletApi.aspx");
    try {
      final body = <String, String>{
        "action": "DR",
        "companyid": companyId,
        "amount": amount.toString(),
      };
      if (staffId != null) body["staffid"] = staffId;
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: body,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("WalletDebit Error: $e");
    }
    return false;
  }

  /// Get wallet balance
  Future<double?> walletBalance(String companyId) async {
    final url = Uri.parse("$baseUrl/WalletApi.aspx?action=GET&companyid=$companyId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data.first['status'] == 'success') {
          return double.tryParse(data.first['balance']?.toString() ?? '0');
        }
      }
    } catch (e) {
      print("WalletBalance Error: $e");
    }
    return null;
  }

  // --- RENEW SUBSCRIPTION ---
  Future<bool> renewSubscription(String staffId, String companyId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/RenewSubscriptionApi.aspx'),
        body: {
          'staffid': staffId,
          'companyid': companyId,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0]['status'] == 'success') {
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Renew Error: $e");
      return false;
    }
  }

  // --- FIELD WORK & FCM TOKEN APIs ---

  Future<String?> getOwnerFcmToken(String companyId) async {
    final url = Uri.parse("$baseUrl/GetOwnerFcmTokenApi.aspx?companyid=$companyId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty && data.first['status'] == 'success') {
          return data.first['fcmtoken']?.toString();
        }
      }
    } catch (e) {
      print("GetOwnerFcmToken Error: $e");
    }
    return null;
  }

  Future<bool> saveFcmToken(String companyId, String token, {String username = ""}) async {
    final url = Uri.parse("$baseUrl/SaveFcmTokenApi.aspx");
    try {
      final response = await http.post(
        url,
        body: {
          "companyid": companyId,
          "fcmtoken": token,
          if (username.isNotEmpty) "username": username,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List && data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("SaveFcmToken Error: $e");
    }
    return false;
  }

  Future<bool> updateFieldWorkerStatus(String companyId, String staffId, String isFieldWorker) async {
    final url = Uri.parse("$baseUrl/FieldApi.aspx");
    try {
      final response = await http.post(
        url,
        body: {
          "action": "UPDATE_FIELDWORKER",
          "companyid": companyId,
          "staffid": staffId,
          "fieldworker": isFieldWorker,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List && data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("UpdateFieldWorker Error: $e");
    }
    return false;
  }

  Future<bool> addFieldLocation(String companyId, String fieldName, String fieldLat, String fieldLong) async {
    final url = Uri.parse("$baseUrl/FieldApi.aspx");
    try {
      final response = await http.post(
        url,
        body: {
          "action": "ADD_FIELD",
          "companyid": companyId,
          "fieldname": fieldName,
          "fieldlat": fieldLat,
          "fieldlong": fieldLong,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List && data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("AddField Error: $e");
    }
    return false;
  }

  Future<List<dynamic>> getFieldLocations(String companyId) async {
    final url = Uri.parse("$baseUrl/FieldApi.aspx?action=GET_FIELDS&companyid=$companyId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("GetFields Error: $e");
    }
    return [];
  }

  Future<bool> assignFieldToStaff(String companyId, String fieldId, String staffId) async {
    final url = Uri.parse("$baseUrl/FieldApi.aspx");
    try {
      final response = await http.post(
        url,
        body: {
          "action": "ASSIGN_FIELD",
          "companyid": companyId,
          "fieldid": fieldId,
          "staffid": staffId,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List && data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("AssignField Error: $e");
    }
    return false;
  }

  Future<bool> unassignFieldFromStaff(String companyId, String fieldId, String staffId) async {
    final url = Uri.parse("$baseUrl/FieldApi.aspx");
    try {
      final response = await http.post(
        url,
        body: {
          "action": "UNASSIGN_FIELD",
          "companyid": companyId,
          "fieldid": fieldId,
          "staffid": staffId,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List && data.isNotEmpty && data.first['status'] == 'success';
      }
    } catch (e) {
      print("UnassignField Error: $e");
    }
    return false;
  }

  Future<List<dynamic>> getFieldAssignments(String companyId, {String staffId = ""}) async {
    final url = Uri.parse("$baseUrl/FieldApi.aspx?action=GET_ASSIGNMENTS&companyid=$companyId${staffId.isNotEmpty ? '&staffid=$staffId' : ''}");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("GetAssignments Error: $e");
    }
    return [];
  }
}
