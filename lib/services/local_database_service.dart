import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'staff_tracking.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE location_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            staff_id TEXT,
            company_id TEXT,
            latitude REAL,
            longitude REAL,
            distance_from_assigned REAL,
            assigned_location_name TEXT,
            breached_geofence INTEGER,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  /// Log a location ping to local SQLite database
  static Future<int> insertLocationLog({
    required String staffId,
    required String companyId,
    required double latitude,
    required double longitude,
    required double distanceFromAssigned,
    required String assignedLocationName,
    required bool breachedGeofence,
  }) async {
    try {
      final database = await db;
      return await database.insert('location_logs', {
        'staff_id': staffId,
        'company_id': companyId,
        'latitude': latitude,
        'longitude': longitude,
        'distance_from_assigned': distanceFromAssigned,
        'assigned_location_name': assignedLocationName,
        'breached_geofence': breachedGeofence ? 1 : 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Error inserting location log to local DB: $e");
      return -1;
    }
  }

  /// Get recent location logs from local database
  static Future<List<Map<String, dynamic>>> getRecentLocationLogs({int limit = 50}) async {
    try {
      final database = await db;
      return await database.query(
        'location_logs',
        orderBy: 'id DESC',
        limit: limit,
      );
    } catch (e) {
      print("Error querying location logs: $e");
      return [];
    }
  }

  /// Clear old logs older than N days
  static Future<int> clearOldLogs({int daysToKeep = 7}) async {
    try {
      final database = await db;
      final cutoff = DateTime.now().subtract(Duration(days: daysToKeep)).toIso8601String();
      return await database.delete(
        'location_logs',
        where: 'timestamp < ?',
        whereArgs: [cutoff],
      );
    } catch (e) {
      print("Error clearing old location logs: $e");
      return 0;
    }
  }
}
