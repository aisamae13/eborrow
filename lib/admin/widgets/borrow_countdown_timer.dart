import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

/// Displays a live countdown for approved/active requests.
class BorrowCountdownTimer extends StatefulWidget {
  final DateTime borrowDate;
  final DateTime returnDate;
  final String status;
  final VoidCallback? onFinished;
  final Duration tick;
  final bool compact;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  const BorrowCountdownTimer({
    super.key,
    required this.borrowDate,
    required this.returnDate,
    required this.status,
    this.onFinished,
    this.tick = const Duration(seconds: 1),
    this.compact = false,
    this.padding = const EdgeInsets.all(8),
    this.elevated = true,
  });

  @override
  State<BorrowCountdownTimer> createState() => _BorrowCountdownTimerState();
}

class _BorrowCountdownTimerState extends State<BorrowCountdownTimer> {
  Timer? _timer;
  late DateTime _now;
  bool _hasCalledOnFinished = false;
  bool _forceShowDuration = true; // Added to force duration display

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    final status = widget.status.toLowerCase();
    if (status == 'overdue') return;

    _timer = Timer.periodic(widget.tick, (_) {
      if (!mounted) return;
      
      setState(() {
        _now = DateTime.now();
      });
      
      // Handle overdue transition
      if (_now.isAfter(widget.returnDate)) {
        _timer?.cancel();
        _timer = null;
        _triggerOverdueVibration();
        if (!_hasCalledOnFinished && widget.onFinished != null) {
          _hasCalledOnFinished = true;
          Future.microtask(widget.onFinished!);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status.toLowerCase();
    
    // SPECIAL CASE: Always show duration for approved/pending
    late String phaseLabel;
    late Duration diff;
    bool isOverdue = false;
    bool isStatic = false;
    
    if (status == 'approved' || status == 'pending') {
      if (_forceShowDuration) {
        // Always show borrow period duration for approved/pending
        phaseLabel = 'Duration';
        diff = widget.returnDate.difference(widget.borrowDate);
        // Simulate countdown by decreasing seconds
        if (_timer != null) {
          final elapsedSecs = (_now.millisecondsSinceEpoch ~/ 1000) % 60;
          diff = Duration(seconds: diff.inSeconds - elapsedSecs % 60);
        }
      } else if (_now.isBefore(widget.borrowDate)) {
        phaseLabel = 'Starts in';
        diff = widget.borrowDate.difference(_now);
      } else if (_now.isBefore(widget.returnDate)) {
        phaseLabel = 'Time left';
        diff = widget.returnDate.difference(_now);
      } else {
        phaseLabel = 'Overdue by';
        diff = _now.difference(widget.returnDate);
        isOverdue = true;
        isStatic = true;
      }
    } else if (status == 'active') {
      if (_now.isBefore(widget.returnDate)) {
        phaseLabel = 'Time left';
        diff = widget.returnDate.difference(_now);
      } else {
        phaseLabel = 'Overdue by';
        diff = _now.difference(widget.returnDate);
        isOverdue = true;
        isStatic = true;
      }
    } else if (status == 'overdue') {
      phaseLabel = 'Overdue by';
      diff = _now.difference(widget.returnDate);
      isOverdue = true;
      isStatic = true;
    } else {
      phaseLabel = 'Duration';
      diff = widget.returnDate.difference(widget.borrowDate);
    }

    final seg = _formatDuration(diff);
    final color = _getUrgencyColor(diff, isOverdue);

    return widget.compact
        ? _buildCompact(phaseLabel, seg, color, isOverdue, isStatic)
        : _buildFull(phaseLabel, seg, color, isOverdue, isStatic);
  }

  Widget _buildFull(
    String phase,
    _DurationSegments seg,
    Color color,
    bool isOverdue,
    bool isStatic,
  ) {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.withOpacity(0.08) : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.4) : color.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: widget.elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                phase,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: isOverdue ? Colors.red : color,
                ),
              ),
              if (isStatic) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'STATIC',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _timeChip('${seg.days}', 'D', isOverdue),
              _timeChip('${seg.hours}', 'H', isOverdue),
              _timeChip('${seg.minutes}', 'M', isOverdue),
              _timeChip('${seg.seconds}', 'S', isOverdue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(
    String phase,
    _DurationSegments seg,
    Color color,
    bool isOverdue,
    bool isStatic,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
          size: 16,
          color: isOverdue ? Colors.red : color,
        ),
        const SizedBox(width: 4),
        Text(
          '$phase: ${seg.days}d ${seg.hours}h ${seg.minutes}m ${seg.seconds}s',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isOverdue ? Colors.red : color,
          ),
        ),
        if (isStatic) ...[
          const SizedBox(width: 4),
          Text(
            '(STATIC)',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: (isOverdue ? Colors.red : Colors.blue).withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _timeChip(String value, String label, bool isOverdue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.white,
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.3) : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1,
              color: isOverdue ? Colors.red : Colors.black,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: isOverdue ? Colors.red.withOpacity(0.8) : Colors.grey[600],
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  _DurationSegments _formatDuration(Duration d) {
    var total = d.inSeconds;
    if (total < 0) total = 0;
    final days = total ~/ 86400;
    final hours = (total % 86400) ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    return _DurationSegments(days: days, hours: hours, minutes: minutes, seconds: seconds);
  }

  Color _getUrgencyColor(Duration diff, bool isOverdue) {
    if (isOverdue) return Colors.red;
    if (diff.inMinutes <= 30) return Colors.red;
    if (diff.inHours <= 6) return Colors.orange;
    if (diff.inHours <= 24) return Colors.amber.shade700;
    return const Color(0xFF2B326B);
  }

  Future<void> _triggerOverdueVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500, 200, 500],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    } catch (_) {}
  }
}

class _DurationSegments {
  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  _DurationSegments({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });
}

Duration? computeRemainingUntil(DateTime? target) {
  if (target == null) return null;
  return target.difference(DateTime.now());
}