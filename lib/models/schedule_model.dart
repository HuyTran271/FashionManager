class Schedule {
  final int? id;
  final int? outfitId;
  final DateTime scheduledDate;
  final String? eventName;
  final String? note;
  final bool isNotified;

  Schedule({
    this.id,
    this.outfitId,
    required this.scheduledDate,
    this.eventName,
    this.note,
    this.isNotified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outfitId': outfitId,
      'scheduledDate': scheduledDate.toIso8601String(),
      'eventName': eventName,
      'note': note,
      'isNotified': isNotified ? 1 : 0,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'],
      outfitId: map['outfitId'],
      scheduledDate: DateTime.parse(map['scheduledDate']),
      eventName: map['eventName'],
      note: map['note'],
      isNotified: map['isNotified'] == 1,
    );
  }

  Schedule copyWith({
    int? id,
    int? outfitId,
    DateTime? scheduledDate,
    String? eventName,
    String? note,
    bool? isNotified,
  }) {
    return Schedule(
      id: id ?? this.id,
      outfitId: outfitId ?? this.outfitId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      eventName: eventName ?? this.eventName,
      note: note ?? this.note,
      isNotified: isNotified ?? this.isNotified,
    );
  }
}