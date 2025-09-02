import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'landingpage.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not found.';
      }
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();

      setState(() {
        _profileData = response;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching profile: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    try {
      await supabase.auth.signOut();
      await navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LandingPage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // 1. ADDED: Function to show the edit dialog
  void _showEditStudentIdDialog() {
    final studentIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Student ID'),
          content: TextField(
            controller: studentIdController,
            decoration: const InputDecoration(hintText: "Your Student ID"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateStudentId(studentIdController.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // 2. ADDED: Function to update the student_id in the database
  Future<void> _updateStudentId(String newId) async {
    if (newId.isEmpty) {
      return;
    }
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not found.';
      }
      await supabase
          .from('user_profiles')
          .update({'student_id': newId})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student ID updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchProfile();
      }
    } on PostgrestException catch (e) {
      // This block specifically catches errors from the Supabase database
      if (mounted) {
        String errorMessage = 'Error updating Student ID.';
        // We check for the specific error code for a duplicate entry (23505)
        if (e.code == '23505') {
          errorMessage =
              'This Student ID is already taken. Please use a different one.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      // This block catches any other general errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An unexpected error occurred.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2B326B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildProfileInfoCard(),
                const SizedBox(height: 24),
                _buildOptionTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
                _buildOptionTile(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  onTap: _signOut,
                  isDestructive: true,
                ),
              ],
            ),
    );
  }

  Widget _buildProfileInfoCard() {
    final studentId = _profileData?['student_id'];
    final hasStudentId = studentId != null && studentId.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment
            .stretch, // This property is now correctly placed here
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF2B326B),
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            '${_profileData?['first_name'] ?? ''} ${_profileData?['last_name'] ?? ''}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Custom Row for Student ID with Edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student ID:',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              Row(
                children: [
                  Text(
                    hasStudentId ? studentId! : 'Not Set',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: hasStudentId ? Colors.black87 : Colors.red,
                    ),
                  ),
                  // Conditionally show the edit button
                  if (!hasStudentId)
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.blue,
                      ),
                      onPressed: _showEditStudentIdDialog,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(left: 8),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 4),
          _buildInfoRow('Email:', _profileData?['email'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8.0,
      ), // Adds spacing between rows
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Aligns items to the ends
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end, // Aligns the text to the right
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              overflow:
                  TextOverflow.ellipsis, // Prevents overflow with long text
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : Colors.black87;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
