import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/location_provider.dart';
import '../../providers/pet_provider.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

class TrackReplayScreen extends ConsumerStatefulWidget {
  const TrackReplayScreen({super.key});

  @override
  ConsumerState<TrackReplayScreen> createState() => _TrackReplayScreenState();
}

class _TrackReplayScreenState extends ConsumerState<TrackReplayScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(hours: 6));
  DateTime _to = DateTime.now();
  bool _isPlaying = false;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final petId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Track Replay')),
      body: Column(
        children: [
          // Date range selector
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: 'From',
                      date: _from,
                      onTap: () async {
                        final picked = await showDateTimePicker(context, _from);
                        if (picked != null) setState(() => _from = picked);
                      },
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  Expanded(
                    child: _DateButton(
                      label: 'To',
                      date: _to,
                      onTap: () async {
                        final picked = await showDateTimePicker(context, _to);
                        if (picked != null) setState(() => _to = picked);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Track map
          Expanded(
            child: petId == null
                ? const Center(child: Text('No pet selected'))
                : ref.watch(trackReplayProvider((
                    petId: petId,
                    from: _from,
                    to: _to,
                  ))).when(
                    data: (points) {
                      if (points.isEmpty) {
                        return const Center(
                          child: Text('No track data for this period'),
                        );
                      }
                      return Stack(
                        children: [
                          Container(
                            color: Colors.grey[300],
                            child: Center(
                              child: Text(
                                '${points.length} track points',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
          ),
          // Playback controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Slider(
                  value: _currentIndex.toDouble(),
                  min: 0,
                  max: 100,
                  onChanged: (v) =>
                      setState(() => _currentIndex = v.toInt()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: () => setState(() => _currentIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: () =>
                          setState(() => _isPlaying = !_isPlaying),
                      mini: true,
                      backgroundColor: AppColors.primary,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: () => setState(() => _currentIndex = 100),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> showDateTimePicker(
      BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              Formatters.dateTime(date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
