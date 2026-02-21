import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Wallet',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.deepPurple[800],
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Wallet'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Colors.deepPurple[300],
            ),
            const SizedBox(height: 20),
            Text(
              'Manage Your Game Wallet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCoinScreen(userId: '1'),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Money to Wallet'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: Colors.deepPurple.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddCoinScreen extends StatefulWidget {
  final String userId;

  const AddCoinScreen({super.key, required this.userId});

  @override
  _AddCoinScreenState createState() => _AddCoinScreenState();
}

class _AddCoinScreenState extends State<AddCoinScreen> {
  final TextEditingController amountController = TextEditingController();
  double walletBalance = 0.0;
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;

  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String profilePictureUrl = '';

  @override
  void initState() {
    super.initState();
    fetchWalletData();
  }

  Future<void> fetchWalletData() async {
    final url = Uri.parse(
        'https://ludo.eventsystem.online/api/wallet/wallet.php?user_id=${widget.userId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final user = data['user'];
          setState(() {
            walletBalance = double.tryParse(user['coin'].toString()) ?? 0.0;
            userName = user['name'] ?? 'User';
            userEmail = user['email'] ?? 'user@gmail.com';
            userPhone = user['phone_number'] ?? '9999999999';
            profilePictureUrl = user['profile_picture'] ?? '';
            transactions = (user['transactions'] as List).map((tx) {
              return {
                'amount': double.tryParse(tx['amount'].toString()) ?? 0.0,
                'description': tx['transaction_type'],
                'date': tx['created_at'].substring(0, 10),
              };
            }).toList();
            isLoading = false;
          });
        } else {
          showError(data['message']);
        }
      } else {
        showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      showError('Error: $e');
    }
  }

  Future<void> initiatePayment() async {
    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    String txnId = DateTime.now().millisecondsSinceEpoch.toString();
    String productInfo = 'Wallet Recharge';

    try {
      final response = await http.post(
        Uri.parse("https://ludo.eventsystem.online/api/wallet/generate_hash.php"),
        body: {
          "txnid": txnId,
          "amount": amount.toStringAsFixed(2),
          "productinfo": productInfo,
          "firstname": userName,
          "email": userEmail,
        },
      );

      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        String merchantKey = data['key'];
        String hash = data['hash'];

        String paymentUrl = 'https://test.payu.in/_payment';

        String successUrl = 'https://ludo.eventsystem.online/api/wallet/surl.php?'
            'amount=${amount.toStringAsFixed(2)}'
            '&user_id=${widget.userId}';

        String paymentParameters =
            'key=$merchantKey&txnid=$txnId&amount=${amount.toStringAsFixed(2)}&productinfo=$productInfo'
            '&firstname=$userName&email=$userEmail&phone=$userPhone'
            '&surl=${Uri.encodeComponent(successUrl)}'
            '&furl=https://ludo.eventsystem.online/api/wallet/furl.php'
            '&hash=$hash';

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PaymentWebView(
              paymentUrl: paymentUrl,
              paymentParameters: paymentParameters,
              onPaymentSuccess: addMoney,
              userId: widget.userId,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      } else {
        showError("Failed to generate hash from server");
      }
    } catch (e) {
      showError('Error: $e');
    }
  }

  Future<void> addMoney(double amount) async {
    final url = Uri.parse('https://ludo.eventsystem.online/api/wallet/add_money.php');
    final response = await http.post(url, body: {
      'user_id': widget.userId,
      'amount': amount.toString(),
    });
    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₹${amount.toStringAsFixed(2)} added successfully!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        transactions.insert(0, {
          'amount': amount,
          'description': 'Added Money',
          'date': DateTime.now().toString().substring(0, 10),
        });
        walletBalance += amount;
      });
      amountController.clear();
    } else {
      String errorMessage = data['message'] ?? 'Failed to add money.';
      showError(errorMessage);
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      size: 50,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add Money to Your Wallet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.currency_rupee),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: initiatePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                        shadowColor: Colors.deepPurple.withOpacity(0.3),
                      ),
                      child: const Text(
                        'Add Money',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Transaction History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No transactions yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple[100],
                                child: Icon(
                                  Icons.currency_rupee,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              title: Text(
                                '₹${tx['amount'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(tx['description']),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    tx['date'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green[400],
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}

class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final String paymentParameters;
  final Function(double) onPaymentSuccess;
  final String userId;

  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.paymentParameters,
    required this.onPaymentSuccess,
    required this.userId,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  bool _isLoading = true;

  void _handleUrlChange(String url) {
    setState(() => _isLoading = false);
    if (url.contains('ludo.eventsystem.online/api/wallet/surl.php')) {
      final params = Uri.parse(url).queryParameters;
      final amount = double.tryParse(params['amount'] ?? '0') ?? 0.0;
      final userId = params['user_id'];

      if (mounted) Navigator.pop(context);
      if (amount > 0 && userId != null) {
        widget.onPaymentSuccess(amount);
      }
    } else if (url.contains('ludo.eventsystem.online/api/wallet/furl.php')) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment failed! Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final htmlContent = '''
    <html>
      <body onload="document.forms[0].submit()">
        <form method="post" action="${widget.paymentUrl}">
          ${widget.paymentParameters.split('&').map((param) {
      final parts = param.split('=');
      final key = Uri.decodeComponent(parts[0]);
      final value = parts.length > 1 ? Uri.decodeComponent(parts[1]) : '';
      return '<input type="hidden" name="$key" value="$value"/>';
    }).join()}
        </form>
      </body>
    </html>
    ''';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Gateway'),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(
              data: htmlContent,
              mimeType: 'text/html',
              encoding: 'utf-8',
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
            ),
            onWebViewCreated: (_) => setState(() => _isLoading = true),
            onLoadStart: (_, url) => setState(() => _isLoading = true),
            onLoadStop: (_, url) {
              if (url != null) _handleUrlChange(url.toString());
            },
            onUpdateVisitedHistory: (_, url, __) {
              if (url != null) _handleUrlChange(url.toString());
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
