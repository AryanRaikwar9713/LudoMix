import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_logger.dart';
import 'wallet_history_screen.dart';

class WalletScreen extends StatefulWidget {
  final String userId;

  const WalletScreen({super.key, required this.userId});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final Logger _logger = Logger();
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

    _logger.i('Wallet API REQUEST → URL: $url');
    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );

      _logger.i(
          'Wallet API RESPONSE → URL: $url, status: ${response.statusCode}, rawBody: ${response.body}');

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _logger.i('Wallet API DECODED SUCCESS → URL: $url, data: $data');

        if (data['status'] == 'success') {
          final user = data['user'];
          if (!mounted) return;
          setState(() {
            userName = user['name'];
            profilePic = _fixProfilePictureUrl(user['profile_picture'] ?? '');
            walletBalance = double.tryParse(user['coin'].toString()) ?? 0.0;
            isLoading = false;
          });
        } else {
          _logger.e(
              'Wallet API STATUS ERROR → URL: $url, message: ${data['message']}');
          setState(() {
            isLoading = false;
            isError = true;
            errorMsg = data['message'];
          });
        }
      } else {
          _logger.e(
              'Wallet API HTTP ERROR → URL: $url, status: ${response.statusCode}, body: ${response.body}');
        setState(() {
          isLoading = false;
          isError = true;
          errorMsg = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      _logger.e('Wallet API EXCEPTION → URL: $url, error: $e');
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

  /// Fix profile picture URL (handles double-domain bug)
  String _fixProfilePictureUrl(String url) {
    if (url.isEmpty) return '';

    // If backend returned something like
    // "https://ludo.eventsystem.onlinehttps://lh3.googleusercontent.com/..."
    if (url.startsWith('https://ludo.eventsystem.onlinehttps://')) {
      return url.replaceFirst('https://ludo.eventsystem.online', '');
    }

    // If already a valid absolute URL, keep as is
    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme && uri.hasAuthority) {
        return url;
      }
    } catch (_) {
      return '';
    }

    return '';
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
        title: const Text('Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Game History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WalletHistoryScreen(userId: widget.userId),
                ),
              );
            },
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
