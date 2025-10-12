import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/main.dart';
import '../services/admin_service.dart';

const Color primaryAdminColor = Color(0xFF2B326B);
const Color suspendedColor = Color.fromARGB(255, 255, 175, 45);
const Color deleteColor = Colors.red;

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _refreshKey = 0;
  
  // Add this map to track real-time user states
  Map<String, Map<String, dynamic>> _userStateOverrides = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _refreshKey++;
      _userStateOverrides.clear(); // Clear overrides on refresh
    });
  }

  // Add method to update user state locally
  void _updateUserStateLocally(String userId, Map<String, dynamic> updates) {
    setState(() {
      _userStateOverrides[userId] = {
        ...(_userStateOverrides[userId] ?? {}),
        ...updates,
      };
    });
  }

  // Add method to remove user locally
  void _removeUserLocally(String userId) {
    setState(() {
      _userStateOverrides[userId] = {'_deleted': true};
    });
  }

  String getInitials(String fullName) {
    if (fullName.isEmpty) return '??';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    }
    return fullName[0].toUpperCase();
  }

  List<Map<String, dynamic>> _filterAndSortUsers(
    List<Map<String, dynamic>> users,
    String currentUserId,
  ) {
    var filteredUsers = users.where((user) {
      final userIdFromDb = user['id'] as String;
      if (userIdFromDb == currentUserId) return false;

      // Check if user is marked as deleted locally
      if (_userStateOverrides[userIdFromDb]?['_deleted'] == true) {
        return false;
      }

      if (_searchQuery.isEmpty) return true;

      final firstName = (user['first_name'] ?? '').toLowerCase();
      final lastName = (user['last_name'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final studentId = (user['student_id'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();

      return firstName.contains(query) ||
          lastName.contains(query) ||
          email.contains(query) ||
          studentId.contains(query);
    }).toList();

    // Apply local state overrides
    filteredUsers = filteredUsers.map((user) {
      final userId = user['id'] as String;
      final overrides = _userStateOverrides[userId];
      if (overrides != null) {
        return {...user, ...overrides};
      }
      return user;
    }).toList();

    filteredUsers.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '');
      final bDate = DateTime.tryParse(b['created_at'] ?? '');
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    return filteredUsers;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Borrower Management')),
        body: const Center(
          child: CircularProgressIndicator(color: primaryAdminColor),
        ),
      );
    }

    final currentUserId = currentUser.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Borrower Management',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryAdminColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: primaryAdminColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, email, or student ID...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_refreshKey),
              stream: supabase.from('user_profiles').stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryAdminColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading users: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final rawUsers = snapshot.data ?? [];
                final users = _filterAndSortUsers(rawUsers, currentUserId);

                if (users.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      _refreshData();
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty
                                    ? Icons.people_outline
                                    : Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No borrower accounts found.'
                                    : 'No results found for "$_searchQuery"',
                                style: GoogleFonts.poppins(
                                  fontSize: 16.0,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _refreshData();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final userId = user['id'] as String;

                      final firstName = user['first_name'] ?? '';
                      final lastName = user['last_name'] ?? '';
                      final fullName = '$firstName $lastName'.trim().isEmpty
                          ? 'No Name'
                          : '$firstName $lastName'.trim();

                      final studentNumber = user['student_id'] ?? 'N/A';
                      final email = user['email'] ?? 'No email';
                      final isSuspended = user['is_suspended'] ?? false;
                      final initials = getInitials(fullName);
                      final createdAt = DateTime.tryParse(user['created_at'] ?? '');
                      final avatarUrl = user['avatar_url'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSuspended
                                ? suspendedColor
                                : Colors.grey.shade200,
                            width: isSuspended ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSuspended
                                        ? suspendedColor
                                        : primaryAdminColor,
                                    radius: 28,
                                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null || avatarUrl.isEmpty
                                        ? Text(
                                            initials,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: primaryAdminColor,
                                            decoration: isSuspended
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ID: $studentNumber',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSuspended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: suspendedColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'SUSPENDED',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: suspendedColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Email
                              Row(
                                children: [
                                  Icon(Icons.email_outlined,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Created Date
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    createdAt != null
                                        ? 'Joined ${_formatDate(createdAt)}'
                                        : 'Join date unknown',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _confirmToggleSuspend(
                                              context, userId, isSuspended),
                                      icon: Icon(
                                        isSuspended
                                            ? Icons.play_arrow
                                            : Icons.pause,
                                        size: 18,
                                      ),
                                      label: Text(
                                        isSuspended ? 'Unsuspend' : 'Suspend',
                                        style: GoogleFonts.poppins(fontSize: 13),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isSuspended
                                            ? Colors.green
                                            : suspendedColor,
                                        side: BorderSide(
                                          color: isSuspended
                                              ? Colors.green
                                              : suspendedColor,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _confirmResetPassword(context, email),
                                      icon: const Icon(Icons.lock_reset, size: 18),
                                      label: Text(
                                        'Reset',
                                        style: GoogleFonts.poppins(fontSize: 13),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        side: const BorderSide(color: Colors.blue),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _confirmAndDelete(context, userId),
                                      icon: const Icon(Icons.delete_forever,
                                          size: 18),
                                      label: Text(
                                        'Delete',
                                        style: GoogleFonts.poppins(fontSize: 13),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: deleteColor,
                                        side: const BorderSide(color: deleteColor),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  void _confirmAndDelete(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Confirm Deletion',
            style: GoogleFonts.poppins(
              color: primaryAdminColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete this borrower account? This action cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: deleteColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                
                // ✅ Update UI immediately
                _removeUserLocally(userId);
                
                // Show immediate success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'User account deleted successfully.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Then perform the actual deletion
                AdminService.deleteBorrowerAccount(userId).then((_) {
                  // If deletion fails, we could restore the user
                  print('✅ User deletion completed successfully');
                }).catchError((e) {
                  // If deletion fails, show error and refresh to restore UI
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete user: $e',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _refreshData(); // Refresh to restore the user if deletion failed
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmToggleSuspend(
      BuildContext context, String userId, bool currentlySuspended) {
    final action = currentlySuspended ? 'Unsuspend' : 'Suspend';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            '$action User',
            style: GoogleFonts.poppins(
              color: primaryAdminColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to ${action.toLowerCase()} this borrower account?',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    currentlySuspended ? Colors.green : suspendedColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                action,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                
                // ✅ Update UI immediately
                _updateUserStateLocally(userId, {'is_suspended': !currentlySuspended});
                
                // Show immediate success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'User ${action.toLowerCase()}ed successfully.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Then perform the actual action
                AdminService.toggleSuspendUser(userId, !currentlySuspended).then((_) {
                  print('✅ User suspend/unsuspend completed successfully');
                }).catchError((e) {
                  // If action fails, revert the UI change
                  if (context.mounted) {
                    _updateUserStateLocally(userId, {'is_suspended': currentlySuspended});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to $action user: $e',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmResetPassword(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Reset Password',
            style: GoogleFonts.poppins(
              color: primaryAdminColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Send a password reset email to $email?',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Send',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // ✅ Show immediate success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Password reset email sent to $email',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                
                try {
                  await supabase.auth.resetPasswordForEmail(email);
                  print('✅ Password reset email sent successfully');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to send reset email: $e',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}