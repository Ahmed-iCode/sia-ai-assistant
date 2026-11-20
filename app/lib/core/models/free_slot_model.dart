class FreeSlotModel {
  final DateTime start;
  final DateTime end;
  final int durationMinutes;

  const FreeSlotModel({
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  static DateTime _parseUtcToLocal(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    final str = value.toString().trim();
    if (str.isEmpty) return DateTime.now();
    final hasTimezone = str.endsWith('Z') ||
        str.endsWith('z') ||
        RegExp(r'[+-]\d{2}(:\d{2})?$').hasMatch(str);
    final parsed = DateTime.parse(hasTimezone ? str : '${str}Z');
    return parsed.toLocal();
  }

  factory FreeSlotModel.fromJson(Map<String, dynamic> json) {
    return FreeSlotModel(
      start: _parseUtcToLocal(json['start']),
      end: _parseUtcToLocal(json['end']),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
    );
  }
}
