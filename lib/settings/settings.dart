import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: SettingsPage(),
    debugShowCheckedModeBanner: false,
  ));
}

class SettingsPage extends StatelessWidget {
  // dummy user data
  final String userName = "Aryan Raikwar";
  final String profilePic =
      "https://lh3.googleusercontent.com/a/ACg8ocJh77Fq6UhZYez4T_jxXys5tFPodpWIJ6w_VlUhw6oNjxeE0w=s96-c";

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // logout action
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Logged out")),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(profilePic),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View and edit your profile',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1),
            // Options List
            _buildOptionTile(
              icon: Icons.person,
              title: 'Profile & Manage',
              onTap: () {
                _showMessage(context, 'Profile & Manage clicked');
              },
            ),
            _buildOptionTile(
              icon: Icons.account_balance_wallet,
              title: 'Wallet',
              onTap: () {
                _showMessage(context, 'Wallet clicked');
              },
            ),
            _buildOptionTile(
              icon: Icons.history,
              title: 'Transaction History',
              onTap: () {
                _showMessage(context, 'Transaction History clicked');
              },
            ),
            _buildOptionTile(
              icon: Icons.settings,
              title: 'Game Settings',
              onTap: () {
                _showMessage(context, 'Game Settings clicked');
              },
            ),
            _buildOptionTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                _showMessage(context, 'Help & Support clicked');
              },
            ),
            _buildOptionTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () {
                _showMessage(context, 'Logout clicked');
              },
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple, size: 28),
      title: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isLast
            ? BorderSide.none
            : BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      tileColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
