import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Displays a live countdown for an approved or active borrow request.
///
/// Behavior:
/// - If now < borrowDate  => counts down "Starts in"
/// - Else if now < returnDate => counts down "Time left"
/// - Else => shows "Overdue by ..." (STOPS AUTO-REFRESHING)
class BorrowCountdownTimer extends StatefulWidget {
  final DateTime borrowDate;
  final DateTime returnDate;

  /// Called once when countdown reaches zero (transition point).
  final VoidCallback? onFinished;

  /// How often the timer ticks. Default 1 second.
  final Duration tick;

  /// Compact mode = single line simplified display.
  final bool compact;

  /// Optional decoration wrapper
  final EdgeInsetsGeometry padding;

  /// Optional: force light or dark style
  final bool elevated;

  const BorrowCountdownTimer({
    super.key,
    required this.borrowDate,
    required this.returnDate,
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
  bool _isOverdue = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _checkIfOverdue();
    
    // Only start timer if not already overdue
    if (!_isOverdue) {
      _startTimer();
    }
  }

  void _checkIfOverdue() {
    _isOverdue = _now.isAfter(widget.returnDate);
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.tick, (_) {
      if (!mounted) return;
      
      final newNow = DateTime.now();
      
      // Check if we just became overdue
      final wasOverdue = _isOverdue;
      _isOverdue = newNow.isAfter(widget.returnDate);
      
      setState(() {
        _now = newNow;
      });

      // If we just became overdue, stop the timer and call onFinished
      if (!wasOverdue && _isOverdue) {
        _timer?.cancel();
        _timer = null;
        
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
    final now = _now;
    final beforeStart = now.isBefore(widget.borrowDate);
    final beforeReturn = now.isBefore(widget.returnDate);

    late String phaseLabel;
    late Duration diff;
    bool isOverdue = false;

    if (beforeStart) {
      phaseLabel = 'Starts in';
      diff = widget.borrowDate.difference(now);
    } else if (beforeReturn) {
      phaseLabel = 'Time left';
      diff = widget.returnDate.difference(now);
    } else {
      phaseLabel = 'Overdue by';
      diff = now.difference(widget.returnDate);
      isOverdue = true;
    }

    final segments = _formatDuration(diff);
    final urgencyColor = _getUrgencyColor(diff, isOverdue);

    if (widget.compact) {
      return _buildCompact(phaseLabel, segments, urgencyColor, isOverdue);
    }

    return _buildFull(phaseLabel, segments, urgencyColor, isOverdue);
  }

  Widget _buildFull(
    String phase,
    _DurationSegments seg,
    Color color,
    bool isOverdue,
  ) {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.withOpacity(0.08)
            : color.withOpacity(0.10),
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
              // Add indicator when timer is stopped (overdue)
              if (isOverdue) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'STATIC',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
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
        // Add static indicator for compact mode when overdue
        if (isOverdue) ...[
          const SizedBox(width: 4),
          Text(
            '(STATIC)',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.red.withOpacity(0.7),
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
    int totalSeconds = d.inSeconds;
    if (totalSeconds < 0) totalSeconds = 0;

    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return _DurationSegments(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  Color _getUrgencyColor(Duration diff, bool isOverdue) {
    if (isOverdue) return Colors.red;
    if (diff.inHours <= 1) return Colors.red;
    if (diff.inHours <= 6) return Colors.orange;
    if (diff.inHours <= 24) return Colors.amber.shade700;
    return const Color(0xFF2B326B);
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

/// Utility: Compute remaining Duration (null-safe).
Duration? computeRemainingUntil(DateTime? target) {
  if (target == null) return null;
  final now = DateTime.now();
  return target.difference(now);
}