import 'package:flutter/material.dart';

/// Placeholder Notifications screen — opened from the Home app bar's bell icon.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No notifications yet",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              "We'll let you know when something arrives.",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
