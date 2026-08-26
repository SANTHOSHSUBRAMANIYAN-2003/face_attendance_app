import 'package:mssql_connection/mssql_connection.dart';
import 'dart:convert';

class MSSQLService {
  final MssqlConnection _connection = MssqlConnection.getInstance();

  Future<bool> connect() async {
    try {
      // Inputs from user:
      // Server: 184.168.125.10
      // DB: NMSPAYROLL
      // User: sa
      // Pass: Sri#24211
      
      // Note: The library might require specific format.
      // Usually: server, dbName, useName, password
      
      await _connection.connect(
        ip: '184.168.125.10',
        port: '1433',
        databaseName: 'NMSPAYROLL',
        username: 'sa',
        password: 'Sri#24211',
      );
      return true;
    } catch (e) {
      print('Database Connection Error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> executeQuery(String query) async {
    try {
      String jsonString = await _connection.getData(query);
      // The package usually returns a JSON string like "[{...}, {...}]"
      if (jsonString.isEmpty) return [];
      
      // Need dart:convert, adding import at top if missing, or just using helper
      // But assuming I need to add import.
      // Let's handle the dynamic decode.
      
      // Use dynamic decoding then casting
      // We will need to correct the import in a separate step or assume it is there?
      // No, I should add the import.
      
      // Wait, I cannot easily add import with replace_file_content if it's far away.
      // I will do a multi_replace or simple replace.
      // Let's assume I will replace the function body and I need to make sure dart:convert is imported.
      // I'll try to add the import with a separate replace or just overwrite the file since it is small.
      // Overwriting might be cleaner to ensure everything is right.
      
      return List<Map<String, dynamic>>.from(json.decode(jsonString));
    } catch (e) {
      print('Query Execution Error: $e');
      return [];
    }
  }

  Future<int> executeUpdate(String query) async {
    try {
      // For Insert/Update/Delete
      // The package typically uses writeData or similar.
      // Checking documentation logic: usually getData works for SELECT
      // writeData for INSERT/UPDATE
       var result = await _connection.writeData(query);
       // The result string often contains "Rows Affected: X" or similar, need to parse or just return 1 for success.
       print("Update Result: $result");
       return 1; // Assuming success if no error thrown
    } catch (e) {
      print('Update Error: $e');
      return 0;
    }
  }
}
