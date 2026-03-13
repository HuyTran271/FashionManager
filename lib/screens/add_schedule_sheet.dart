import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class AddScheduleSheet extends StatefulWidget {
  final DateTime initialDate;
  final int? preselectedOutfitId;
  final String? preselectedOutfitName;

  const AddScheduleSheet({
    super.key,
    required this.initialDate,
    this.preselectedOutfitId,
    this.preselectedOutfitName,
  });

  @override
  State<AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<AddScheduleSheet> {
  final _db = DatabaseHelper.instance;
  final _eventController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  int? _selectedOutfitId;
  String? _selectedOutfitName;
  List<Map<String, dynamic>> _outfits = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedTime = TimeOfDay.now();
    _selectedOutfitId = widget.preselectedOutfitId;
    _selectedOutfitName = widget.preselectedOutfitName;
    _loadOutfits();
  }

  Future<void> _loadOutfits() async {
    final outfits = await _db.getAllOutfits();
    if (mounted) {
      setState(() {
        _outfits = outfits;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.black),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.black),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_eventController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập tên sự kiện!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final scheduledDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await _db.insertSchedule({
      'outfitId': _selectedOutfitId,
      'scheduledDate': scheduledDt.toIso8601String(),
      'eventName': _eventController.text.trim(),
      'note': _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      'isNotified': 0,
    });

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final months = ['Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Text(
                  'THÊM LỊCH TRÌNH',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event name
                  const Text('Tên sự kiện *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _eventController,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'VD: Họp quan trọng, Đi chơi...',
                      hintStyle: const TextStyle(
                          color: Colors.black26, fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: const Color(0xFFF7F5F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date & Time row
                  Row(
                    children: [
                      Expanded(
                        child: _buildPickerTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Ngày',
                          value:
                              '${_selectedDate.day} ${months[_selectedDate.month - 1]}',
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPickerTile(
                          icon: Icons.access_time_outlined,
                          label: 'Giờ',
                          value:
                              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Outfit selection
                  const Text('Chọn bộ đồ (tùy chọn)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildOutfitSelector(),
                  const SizedBox(height: 20),

                  // Note
                  const Text('Ghi chú',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Thêm ghi chú...',
                      hintStyle: const TextStyle(color: Colors.black26),
                      filled: true,
                      fillColor: const Color(0xFFF7F5F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Save button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'LƯU LỊCH TRÌNH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitSelector() {
    return Column(
      children: [
        // "No outfit" option
        _buildOutfitOption(null, 'Không chọn bộ đồ', null),
        const SizedBox(height: 8),
        // Outfit options (scrollable horizontally)
        if (_outfits.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _outfits.length,
              itemBuilder: (ctx, i) {
                final o = _outfits[i];
                return _buildOutfitChip(o);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildOutfitOption(int? id, String name, String? occasion) {
    final selected = _selectedOutfitId == id;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedOutfitId = id;
        _selectedOutfitName = id == null ? null : name;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF7F5F2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.do_not_disturb_alt_outlined,
              size: 16,
              color: selected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : Colors.grey,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitChip(Map<String, dynamic> outfit) {
    final selected = _selectedOutfitId == outfit['id'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedOutfitId = outfit['id'];
        _selectedOutfitName = outfit['name'];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: selected
                    ? const BorderRadius.vertical(top: Radius.circular(8))
                    : BorderRadius.circular(10),
                child: Container(
                  color: Colors.grey[100],
                  child: Icon(Icons.style_outlined,
                      color: selected ? Colors.black : Colors.grey[400]),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: selected ? Colors.black : Colors.grey[100],
                borderRadius: selected
                    ? const BorderRadius.vertical(
                        bottom: Radius.circular(8))
                    : const BorderRadius.vertical(
                        bottom: Radius.circular(10)),
              ),
              child: Text(
                outfit['name'] ?? '',
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}