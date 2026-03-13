import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/schedule_model.dart';
import 'add_schedule_sheet.dart';

class CalendarScreen extends StatefulWidget {
  final int? preselectedOutfitId;
  final String? preselectedOutfitName;

  const CalendarScreen({
    super.key,
    this.preselectedOutfitId,
    this.preselectedOutfitName,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;

  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Set<String> _datesWithEvents = {};
  List<Map<String, dynamic>> _daySchedules = [];
  bool _isMonthView = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.forward();
    _loadMonthData();
    _loadDaySchedules(_selectedDay);

    // Nếu được gọi từ OutfitDetail, tự mở sheet lập lịch
    if (widget.preselectedOutfitId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAddSchedule(preselectedDate: _selectedDay);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMonthData() async {
    final dates = await _db.getDatesWithSchedules(
        _focusedMonth.year, _focusedMonth.month);
    if (mounted) setState(() => _datesWithEvents = dates);
  }

  Future<void> _loadDaySchedules(DateTime day) async {
    final schedules = await _db.getSchedulesByDate(day);
    if (mounted) setState(() => _daySchedules = schedules);
  }

  void _onDayTapped(DateTime day) {
    setState(() => _selectedDay = day);
    _loadDaySchedules(day);
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    });
    _loadMonthData();
  }

  Future<void> _openAddSchedule({DateTime? preselectedDate}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddScheduleSheet(
        initialDate: preselectedDate ?? _selectedDay,
        preselectedOutfitId: widget.preselectedOutfitId,
        preselectedOutfitName: widget.preselectedOutfitName,
      ),
    );
    if (result == true) {
      _loadMonthData();
      _loadDaySchedules(_selectedDay);
    }
  }

  Future<void> _deleteSchedule(int id) async {
    await _db.deleteSchedule(id);
    _loadMonthData();
    _loadDaySchedules(_selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildCalendarCard(),
          const SizedBox(height: 8),
          _buildDayHeader(),
          Expanded(child: _buildScheduleList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSchedule(),
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: widget.preselectedOutfitId != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: const Text(
        'LỊCH TRÌNH',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: Colors.black,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: () => setState(() => _isMonthView = !_isMonthView),
          child: Text(
            _isMonthView ? 'TUẦN' : 'THÁNG',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMonthHeader(),
          _buildWeekdayLabels(),
          _isMonthView ? _buildMonthGrid() : _buildWeekRow(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    final months = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
      'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
      'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.black),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: labels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: l == 'CN' ? Colors.red[400] : Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMonthGrid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    // weekday: 1=Mon, 7=Sun
    int startOffset = firstDay.weekday - 1;
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - startOffset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 42));
              }
              final date = DateTime(
                  _focusedMonth.year, _focusedMonth.month, dayNum);
              return Expanded(child: _buildDayCell(date));
            }),
          );
        }),
      ),
    );
  }

  Widget _buildWeekRow() {
    // Show 7 days around selected day
    final weekStart = _selectedDay
        .subtract(Duration(days: _selectedDay.weekday - 1));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(7, (i) {
          final date = weekStart.add(Duration(days: i));
          return Expanded(child: _buildDayCell(date));
        }),
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isToday = _isSameDay(date, DateTime.now());
    final isSelected = _isSameDay(date, _selectedDay);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final hasEvent = _datesWithEvents.contains(dateStr);

    return GestureDetector(
      onTap: () => _onDayTapped(date),
      child: Container(
        height: 42,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black
              : isToday
                  ? Colors.grey[100]
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : date.weekday == 7
                        ? Colors.red[400]
                        : Colors.black87,
              ),
            ),
            if (hasEvent)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white70 : Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader() {
    final weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final months = ['tháng 1', 'tháng 2', 'tháng 3', 'tháng 4', 'tháng 5', 'tháng 6', 'tháng 7', 'tháng 8', 'tháng 9', 'tháng 10', 'tháng 11', 'tháng 12'];
    final weekday = weekdays[_selectedDay.weekday - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            '$weekday, ${_selectedDay.day} ${months[_selectedDay.month - 1]}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          Text(
            '${_daySchedules.length} sự kiện',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_daySchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Ngày này chưa có lịch',
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openAddSchedule(),
              child: const Text('+ Thêm lịch',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: _daySchedules.length,
      itemBuilder: (ctx, i) => _buildScheduleCard(_daySchedules[i]),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final dt = DateTime.parse(schedule['scheduledDate']);
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final hasOutfit = schedule['outfitId'] != null;

    return Dismissible(
      key: Key('sched_${schedule['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteSchedule(schedule['id']),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time column
            Column(
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.grey[300],
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule['eventName'] ?? 'Sự kiện',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hasOutfit) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.style, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          schedule['outfitName'] ?? '',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (schedule['outfitOccasion'] != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              schedule['outfitOccasion'],
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (schedule['note'] != null &&
                      schedule['note'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      schedule['note'],
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Outfit preview thumbnail
            if (hasOutfit) _OutfitThumbnail(outfitId: schedule['outfitId']),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// Small outfit thumbnail for schedule card
class _OutfitThumbnail extends StatelessWidget {
  final int outfitId;
  const _OutfitThumbnail({required this.outfitId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getItemsOfOutfit(outfitId),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final firstItem = snapshot.data!.first;
        final imageFile = File(firstItem['image_path'] ?? '');
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageFile.existsSync()
              ? Image.file(imageFile, width: 44, height: 56, fit: BoxFit.cover)
              : Container(
                  width: 44,
                  height: 56,
                  color: Colors.grey[200],
                  child: const Icon(Icons.checkroom,
                      color: Colors.grey, size: 20),
                ),
        );
      },
    );
  }
}