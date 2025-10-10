import 'package:eborrow/shared/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/main.dart';

class RealtimeNotificationBadge extends StatefulWidget {
  final VoidCallback onTap;

  const RealtimeNotificationBadge({super.key, required this.onTap});

  @override
  State<RealtimeNotificationBadge> createState() => _RealtimeNotificationBadgeState();
}

class _RealtimeNotificationBadgeState extends State<RealtimeNotificationBadge> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeForCurrentUser();
    
    // 🚀 NEW: Listen to auth state changes for real-time account switching
    supabase.auth.onAuthStateChange.listen((data) {
      final newUserId = data.session?.user.id;
      
      // Only reinitialize if the user has actually changed
      if (_currentUserId != newUserId) {
        debugPrint('🔄 User changed from $_currentUserId to $newUserId');
        _currentUserId = newUserId;
        
        if (mounted) {
          _initializeForCurrentUser();
        }
      }
    });
  }

  void _initializeForCurrentUser() {
    final userId = supabase.auth.currentUser?.id;
    
    if (userId != null) {
      debugPrint('🔔 Initializing notifications for user: $userId');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<NotificationProvider>().initializeRealtime(userId);
        }
      });
    } else {
      debugPrint('🚫 No user found, clearing notifications');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Clear notifications when no user is logged in
          context.read<NotificationProvider>().clearNotifications();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;

        return GestureDetector(
          onTap: widget.onTap,
          child: Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 28,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
