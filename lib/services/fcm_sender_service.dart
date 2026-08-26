import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class FcmSenderService {
  static const String _clientEmail =
      "firebase-adminsdk-fbsvc@faceattendance-209d1.iam.gserviceaccount.com";
  static const String _projectId = "faceattendance-209d1";

  static const String _privateKeyPem = '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCyh2gXen3//PoS
EMsDObXpNPfP2qxafiCogEfnhYlZuNDu6icPSdqyw3xfTFXjzVfQY9bT/KdBDaLL
yha1XCed8eEqCH0AwCvViJO5qhWv8O2ndP1Th93hGGcarjTAmi9nD7sc36iXq8cA
IHd3dv4ALgcHJNPgLEUZnmWbpneGPElG2x0GA51Yf90XwB1pKqRfBo3CLJe+sBv9
S00YSZbk22ZRY+xo0VCEWGRDlzkhJQzM8BDB4jVIVTAmJODrhJbB+EjParjbm+3z
AJPFqSqVpw6fl1xl5lbuopASVm6bv7WozTsAb/O+GEtveeJ8lDNNbQu38MsNddJ5
tNAjjlG9AgMBAAECggEAKaaVFpstj747smDIGEPLyLFimlPcT41q/ZzWCbH6GhxX
5FFtFPBITVn1p38V77xtvxC340On2rG9eBl5BE1QcdUnUKjjzvvGjj4bpt6DSkWl
kGKnImiJj5UjotIfPQsLwZnmL8WPXflFx2YLsSup9S1H1vcU1lFFusUdU/u5mW+N
6nDh8URQr5BS26AgDyQ02ULMmjq5q9VGZA4RKB7ORG9F67oa5Hbjfui+6aa+CYZB
OxJTNLRto5LUyVSfJVZtjlLL+re7AUyql7czKn0N20phgq+lOQlM/VRMEbDnLkeW
ynGpJYeT+uNahg3jEyUggtBb8FjOo5H4XFljGSd8gQKBgQDaxvi320rU72uQF/N3
YkWTXMOHiAv5ztPc1vpNuEYzta78YflcbiTpVJFjPZBx8GI924jN3y2HO0rNBZgk
CTxgiSgP1xlYoU7yeVAqsOzIEVtybq6MROmlU+vUkyIUM3FuYFBMQlBMgM7vvlvC
6GbPt2FP5ag1u4LQzYs4Pge7PQKBgQDQ52LWt5Da7jaJr5qO27JsJ8j+VQc/l4yL
iyc9lNjfwRCn6zArGZkCyPP7x8seZsyQvqdWUvALsRIIaNgsxodnD9uQsRjTd3+i
+grGlr9mtZmoa74ZLCItYXsIKhYldDFyBh9v0k7cVkQdZV9resZAkH5R+KvyQFiY
6b6BIzxYgQKBgDvrz2ecGozj3pQi2z5RnjjUaYGPk6giLAkKoJf05tV256ycsQ3N
5TI7RW7nB88NRfsnS/sHK5MkfEJXS+pi1TSjnGNqSLjrxZHIBFsNBm1tw5w+EHS+
0zfDGo6olebuiBzxKE0axJ+PkB4+BygFO1OdKHwXrNC6wQOrqHwJEVkJAoGAYAgu
UIRcK7hcC9lU1J08HSoA5KHTzjDto+xZIp79P4byEC82mmmPBE+6kSDcR+J74YIz
TKSdwtIodwMzdQnijsckaRRwVC3X1+TX9UixPhb3RwwYfFvkbjYkp7EpMxiB7mfQ
JchpBjMF5vmF7tOmtWF3IFmPObLIx6qUL6sx/4ECgYEAyLVwCNDY0ZCVS6b4ZgNo
4Srxa52wyW9NkKE39otOyP0QNRC9yXijz3Be9B556Lu0wvP16wC/Bp+JPWImMHj3
Ydos7hrFcorvUWrOXMfU/5zbz/CaH9Mts6QCBG+3m7vmaDEunSfdz8PbcS2cgzHi
/2qUQr/PxEUK7QdpFeUIBy8=
-----END PRIVATE KEY-----''';

  static String? _cachedAccessToken;
  static DateTime? _accessTokenExpiry;

  /// Generates RS256 JWT assertion and obtains Google OAuth2 access token
  static Future<String?> getAccessToken() async {
    final now = DateTime.now();
    if (_cachedAccessToken != null &&
        _accessTokenExpiry != null &&
        now.isBefore(_accessTokenExpiry!)) {
      return _cachedAccessToken;
    }

    try {
      final jwt = JWT(
        {
          'iss': _clientEmail,
          'scope': 'https://www.googleapis.com/auth/firebase.messaging',
          'aud': 'https://oauth2.googleapis.com/token',
          'exp': (now.millisecondsSinceEpoch ~/ 1000) + 3600,
          'iat': (now.millisecondsSinceEpoch ~/ 1000),
        },
      );

      final rsaKey = RSAPrivateKey(_privateKeyPem);
      final assertion = jwt.sign(rsaKey, algorithm: JWTAlgorithm.RS256);

      final tokenUrl = Uri.parse('https://oauth2.googleapis.com/token');
      final response = await http.post(
        tokenUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': assertion,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int;

        _cachedAccessToken = token;
        // Buffer of 60 seconds
        _accessTokenExpiry = now.add(Duration(seconds: expiresIn - 60));
        return token;
      } else {
        print("OAuth Token Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error acquiring FCM access token: $e");
    }
    return null;
  }

  /// Sends FCM notification directly from the mobile app to a target token
  static Future<bool> sendNotification({
    required String targetToken,
    required String title,
    required String body,
    Map<String, String>? dataPayload,
  }) async {
    if (targetToken.isEmpty) {
      print("Empty FCM target token, skipping push notification.");
      return false;
    }

    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) {
        print("Failed to acquire OAuth access token for FCM.");
        return false;
      }

      final fcmUrl = Uri.parse(
          "https://fcm.googleapis.com/v1/projects/$_projectId/messages:send");

      final message = {
        "message": {
          "token": targetToken,
          "notification": {
            "title": title,
            "body": body,
          },
          "data": {
            "title": title,
            "body": body,
            if (dataPayload != null) ...dataPayload,
          },
          "android": {
            "priority": "HIGH",
            "notification": {
              "channel_id": "bneeds_tracking",
              "sound": "default",
            }
          }
        }
      };

      final response = await http.post(
        fcmUrl,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: json.encode(message),
      );

      if (response.statusCode == 200) {
        print("FCM Push notification sent successfully to $targetToken");
        return true;
      } else {
        print("FCM Send Failed (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("Error sending FCM notification: $e");
    }
    return false;
  }

  /// Convenience method: Fetches owner FCM token for company and sends notification directly to owner
  static Future<bool> notifyOwner({
    required String companyId,
    required String title,
    required String body,
    Map<String, String>? dataPayload,
  }) async {
    try {
      final api = ApiService();
      final ownerToken = await api.getOwnerFcmToken(companyId);
      if (ownerToken != null && ownerToken.isNotEmpty) {
        return await sendNotification(
          targetToken: ownerToken,
          title: title,
          body: body,
          dataPayload: dataPayload,
        );
      } else {
        print("No owner FCM token found for company $companyId");
      }
    } catch (e) {
      print("Error notifying owner: $e");
    }
    return false;
  }
}
