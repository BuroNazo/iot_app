import 'package:flutter/material.dart';
import '../services/schedule_service.dart';

class ScheduleSheet extends StatefulWidget {
  final String deviceId;

  const ScheduleSheet({super.key, required this.deviceId});

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  final ScheduleService _scheduleService = ScheduleService();
  bool _isTimeMode = true;
  bool _isSaving = false;

  TimeOfDay _selectedTime = const TimeOfDay(hour: 22, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

  final TextEditingController _minutesController =
      TextEditingController(text: '15');

  static const Color _neonCyan = Color(0xFF00F5FF);
  static const List<String> _dayLabels = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz'
  ];

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_isTimeMode && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir gun secmelisiniz')),
      );
      return;
    }
    if (!_isTimeMode) {
      final minutes = int.tryParse(_minutesController.text);
      if (minutes == null || minutes <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gecerli bir dakika girin')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    if (_isTimeMode) {
      await _scheduleService.addTimeSchedule(
        widget.deviceId,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        days: _selectedDays.toList()..sort(),
      );
    } else {
      await _scheduleService.addCountdownSchedule(
        widget.deviceId,
        minutes: int.parse(_minutesController.text),
      );
    }
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yeni Zamanlama',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Saat')),
              ButtonSegment(value: false, label: Text('Dakika Sayaci')),
            ],
            selected: {_isTimeMode},
            onSelectionChanged: (selection) =>
                setState(() => _isTimeMode = selection.first),
          ),
          const SizedBox(height: 20),
          if (_isTimeMode) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('Saat', style: TextStyle(color: Colors.white70)),
              trailing: Text(
                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: _neonCyan,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(_dayLabels[i]),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
          ] else ...[
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Dakika',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
