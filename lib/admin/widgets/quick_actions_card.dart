import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickActionsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  const QuickActionsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Grid version for multiple quick actions
class QuickActionsGrid extends StatelessWidget {
  final List<QuickActionItem> actions;
  final int crossAxisCount;
  final double childAspectRatio;

  const QuickActionsGrid({
    super.key,
    required this.actions,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return QuickActionsCard(
          title: action.title,
          icon: action.icon,
          color: action.color,
          onTap: action.onTap,
          subtitle: action.subtitle,
        );
      },
    );
  }
}

// Data model for quick actions
class QuickActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  QuickActionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });
}

// Predefined quick actions for common admin tasks
class AdminQuickActions {
  static List<QuickActionItem> getDefaultActions({
    VoidCallback? onAddEquipment,
    VoidCallback? onGenerateQR,
    VoidCallback? onViewRequests,
    VoidCallback? onManageUsers,
  }) {
    return [
      QuickActionItem(
        title: 'Add Equipment',
        subtitle: 'Add new items',
        icon: Icons.add_circle_outline,
        color: Colors.blue,
        onTap: onAddEquipment ?? () {},
      ),
      QuickActionItem(
        title: 'Generate QR',
        subtitle: 'Create QR codes',
        icon: Icons.qr_code,
        color: Colors.green,
        onTap: onGenerateQR ?? () {},
      ),
      QuickActionItem(
        title: 'View Requests',
        subtitle: 'Manage borrowing',
        icon: Icons.assignment,
        color: Colors.orange,
        onTap: onViewRequests ?? () {},
      ),
      QuickActionItem(
        title: 'Manage Users',
        subtitle: 'User accounts',
        icon: Icons.people,
        color: Colors.purple,
        onTap: onManageUsers ?? () {},
      ),
    ];
  }
}
