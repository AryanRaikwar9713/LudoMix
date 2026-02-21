import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WalletScreen extends StatefulWidget {
  final String userId;

  const WalletScreen({super.key, required this.userId});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String userName = '';
  String profilePic = '';
  double walletBalance = 0.0;
  bool isLoading = true;
  bool isError = false;
  String errorMsg = '';

  @override
  void initState() {
    super.initState();
    fetchWalletData();
  }

  Future<void> fetchWalletData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      isError = false;
      errorMsg = '';
    });
    final url = Uri.parse(
        'https://ludo.eventsystem.online/api/wallet/wallet.php?user_id=${widget.userId}');
    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final user = data['user'];
          if (!mounted) return;
          setState(() {
            userName = user['name'];
            profilePic = user['profile_picture'];
            walletBalance = double.tryParse(user['coin'].toString()) ?? 0.0;
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            isError = true;
            errorMsg = data['message'];
          });
        }
      } else {
        setState(() {
          isLoading = false;
          isError = true;
          errorMsg = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('Failed to fetch') || e.toString().contains('SocketException')
          ? 'Network/CORS error. On Chrome/Web, ensure server has CORS headers. Try mobile app.'
          : 'Error: $e';
      setState(() {
        isLoading = false;
        isError = true;
        errorMsg = msg;
      });
    }
  }

  // Refresh handler
  Future<void> _refresh() async {
    await fetchWalletData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : isError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red, size: 80),
                            SizedBox(height: 20),
                            Text(
                              errorMsg,
                              style: TextStyle(fontSize: 18, color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: fetchWalletData,
                              icon: Icon(Icons.refresh),
                              label: Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Profile & Name
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: profilePic.isNotEmpty
                                  ? NetworkImage(profilePic)
                                  : null,
                              child: profilePic.isEmpty
                                  ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                                  : null,
                            ),
                            SizedBox(height: 15),
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'User ID: ${widget.userId}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 30),
                            // Wallet Balance Card
                            _buildWalletCard(theme),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Icon with animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: value,
                    child: Icon(Icons.account_balance_wallet,
                        size: 50, color: Colors.white),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              'Wallet Balance',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '₹${walletBalance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 10),
            // Decorative animated effect
            _buildAnimatedWave(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWave() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 2 * 3.14),
      duration: Duration(seconds: 3),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value,
          child: Icon(Icons.blur_on, size: 60, color: Colors.white24),
        );
      },
    );
  }
}
