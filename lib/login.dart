import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'register.dart'; // Assuming your register page file is named register.dart
import 'home_screen.dart'; // Assuming your home screen file is named home_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart'; // For SVG assets
import 'package:lottie/lottie.dart'; // For Lottie animations
import 'package:google_fonts/google_fonts.dart'; // For custom fonts

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController numberController = TextEditingController(
    text: '9998887776',
  );
  final TextEditingController pinController =
      TextEditingController(text: '987654');

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    loadUserDetails();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    numberController.dispose();
    pinController.dispose();
    super.dispose();
  }

  void loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    numberController.text = prefs.getString('phone_number') ?? '';
    pinController.text = prefs.getString('pin') ?? '';
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    final response = await http.post(
      Uri.parse('https://ludo.eventsystem.online/api/login.php'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'phone_number': numberController.text,
        'pin': pinController.text,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success']) {
        final userId = responseData['user_id'].toString();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone_number', numberController.text);
        await prefs.setString('pin', pinController.text);
        await prefs.setString('user_id', userId);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen(userId: userId)),
        );
      } else {
        _showErrorToast(
            responseData['message'] ?? "Invalid phone number or PIN.");
      }
    } else {
      _showErrorToast("Failed to connect to the server.");
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled sign-in

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print("Error signing in with Google: $e");
      _showErrorToast("Google sign-in failed. Please try again.");
      return null;
    }
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.redAccent, // Changed to red for errors
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade900,
                  Colors.blue.shade700,
                  Colors.blue.shade500,
                ],
              ),
            ),
          ),

          // Optional: Lottie animations or other decorative elements
          Positioned(
            top: size.height * 0.1,
            left: size.width * 0.1,
            child: Transform.rotate(
              angle: -0.2, // Rotate slightly
              child: Lottie.asset(
                'assets/lottie/dice_blue.json', // Use a blue-themed Lottie if available
                width: size.width * 0.2,
                height: size.width * 0.2,
                repeat: true,
                animate: true,
              ),
            ),
          ),

          Positioned(
            bottom: size.height * 0.15,
            right: size.width * 0.1,
            child: Transform.rotate(
              angle: 0.3, // Rotate slightly
              child: Lottie.asset(
                'assets/lottie/coins_blue.json', // Use a blue-themed Lottie if available
                width: size.width * 0.25,
                height: size.width * 0.25,
                repeat: true,
                animate: true,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    elevation: 15.0, // Increased elevation
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.0), // More rounded
                    ),
                    color: Colors.white
                        .withOpacity(0.95), // Slightly transparent white card
                    child: Container(
                      width: size.width * 0.9,
                      padding: const EdgeInsets.all(25.0), // Increased padding
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App Logo/Title with animation
                            Hero(
                              tag: 'app-logo',
                              child: Image.asset(
                                'assets/images/board.png', // Use your actual logo path
                                height: size.height * 0.12,
                              ),
                            ),

                            const SizedBox(height: 25), // Increased spacing

                            // Welcome text with blue color
                            Text(
                              'Welcome Back!',
                              style: GoogleFonts.poppins(
                                // Using Poppins font
                                fontSize:
                                    size.width * 0.07, // Responsive font size
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900, // Deep blue color
                              ),
                            ),

                            const SizedBox(height: 30), // Increased spacing

                            // Phone Number Field
                            TextFormField(
                              controller: numberController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.poppins(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                labelStyle:
                                    GoogleFonts.poppins(color: Colors.blueGrey),
                                prefixIcon: Icon(Icons.phone_android,
                                    color: Colors.blueAccent), // Blue icon
                                filled: true,
                                fillColor: Colors.blue.shade50
                                    .withOpacity(0.5), // Light blue fill
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(15), // More rounded
                                  borderSide:
                                      BorderSide(color: Colors.blue.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                      color: Colors.blueAccent, width: 2),
                                ),
                                errorStyle: GoogleFonts.poppins(
                                    color: Colors.redAccent, fontSize: 12),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                // Add more specific phone number validation if needed
                                return null;
                              },
                            ),

                            const SizedBox(height: 20), // Increased spacing

                            // PIN Field
                            TextFormField(
                              controller: pinController,
                              obscureText: true,
                              style: GoogleFonts.poppins(color: Colors.black87),
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly, // Only allow digits
                              ],
                              decoration: InputDecoration(
                                labelText: '6-Digit PIN',
                                labelStyle:
                                    GoogleFonts.poppins(color: Colors.blueGrey),
                                prefixIcon: Icon(Icons.lock_outline,
                                    color: Colors.blueAccent), // Blue icon
                                filled: true,
                                fillColor: Colors.blue.shade50
                                    .withOpacity(0.5), // Light blue fill
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(15), // More rounded
                                  borderSide:
                                      BorderSide(color: Colors.blue.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                      color: Colors.blueAccent, width: 2),
                                ),
                                errorStyle: GoogleFonts.poppins(
                                    color: Colors.redAccent, fontSize: 12),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your PIN';
                                }
                                if (value.length != 6) {
                                  return 'PIN must be 6 digits';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 30), // Increased spacing

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: loginUser,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white, // White text
                                  backgroundColor:
                                      Colors.blue.shade800, // Deep blue button
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18), // Increased padding
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        15), // More rounded
                                  ),
                                  elevation: 8, // Increased elevation
                                  shadowColor: Colors.blue.shade800
                                      .withOpacity(0.5), // Blue shadow
                                ),
                                child: Text(
                                  'LOGIN',
                                  style: GoogleFonts.poppins(
                                    // Using Poppins font
                                    fontSize: size.width *
                                        0.048, // Responsive font size
                                    fontWeight: FontWeight.bold,
                                    letterSpacing:
                                        1.5, // Increased letter spacing
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20), // Increased spacing

                            // OR divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.blueGrey.withOpacity(0.5),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal:
                                          15), // Increased horizontal padding
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.poppins(
                                      // Using Poppins font
                                      color: Colors.blueGrey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.blueGrey.withOpacity(0.5),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20), // Increased spacing

                            // Google Sign-In Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  User? user = await signInWithGoogle();
                                  if (user != null && mounted) {
                                    // Navigate to HomeScreen with user ID if login is successful
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            HomeScreen(userId: user.uid),
                                      ),
                                    );
                                  }
                                },
                                icon: SvgPicture.asset(
                                  'assets/svg/google.svg', // Use your Google SVG asset
                                  height: 24,
                                ),
                                label: Text(
                                  'Sign in with Google',
                                  style: GoogleFonts.poppins(
                                    // Using Poppins font
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: size.width *
                                        0.045, // Responsive font size
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16), // Increased padding
                                  backgroundColor:
                                      Colors.white, // White background
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        15), // More rounded
                                  ),
                                  elevation: 5,
                                ),
                              ),
                            ),

                            const SizedBox(height: 25), // Increased spacing

                            // Register Link
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: "Don't have an account? ",
                                  style: GoogleFonts.poppins(
                                      color: Colors
                                          .blueGrey.shade700), // BlueGrey text
                                  children: [
                                    TextSpan(
                                      text: 'Register Now',
                                      style: GoogleFonts.poppins(
                                        // Using Poppins font
                                        color: Colors
                                            .blue.shade800, // Deep blue link
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
