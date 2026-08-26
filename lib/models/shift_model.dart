class Shift {
  final int shiftId;
  final String shiftName;
  final String shiftStart; // keeping as String for simplicity with API (TIME type)
  final String shiftEndTime; // keeping as String for simplicity with API (TIME type)
  final int companyId;

  Shift({
    required this.shiftId,
    required this.shiftName,
    required this.shiftStart,
    required this.shiftEndTime,
    required this.companyId,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      shiftId: json['shiftid'] is int ? json['shiftid'] : int.parse(json['shiftid'].toString()),
      shiftName: json['shiftname'] ?? '',
      shiftStart: json['shiftstart'] ?? '',
      shiftEndTime: json['shiftendtime'] ?? '',
      companyId: json['companyid'] is int ? json['companyid'] : int.parse(json['companyid'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shiftid': shiftId,
      'shiftname': shiftName,
      'shiftstart': shiftStart,
      'shiftendtime': shiftEndTime,
      'companyid': companyId,
    };
  }
}
