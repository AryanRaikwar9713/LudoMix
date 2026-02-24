import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'login.dart';
import 'match_options.dart';
import 'wallet_screen.dart';
import 'add_coin.dart';
import 'settings/settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AudioPlayer? _audioPlayer;
  bool _isMusicPlaying = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  int _coins = 0;
  String? _firebaseUid;
  String? _dbUserId;
  String _userName = 'User';
  String _profilePicture = '';

  @override
  void initState() {
    super.initState();
    _initMusic();
    _checkAndCreateUser();
    _fetchUserData();
    _dbUserId = widget.userId;
  }

  Future<void> _fetchUserData() async {
    if (_dbUserId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://ludo.eventsystem.online/api/wallet/wallet.php?user_id=$_dbUserId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _coins = int.tryParse(data['user']['coin'].toString()) ?? 0;
            _userName = data['user']['name'] ?? 'User';
            _profilePicture = data['user']['profile_picture'] ?? '';
            if (_profilePicture
                .startsWith('https://ludo.eventsystem.onlinehttps://')) {
              _profilePicture =
                  _profilePicture.replaceFirst('https://ludo.eventsystem.online', '');
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> _checkAndCreateUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _firebaseUid = user.uid;

      final response = await http.post(
        Uri.parse('https://ludo.eventsystem.online/api/create_or_get_user.php'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'firebase_uid': user.uid,
          'phone_number': user.phoneNumber ?? '',
          'name': user.displayName ?? 'User',
          'profile_picture': user.photoURL ?? '',
          'pin': null
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          setState(() {
            _dbUserId = responseData['user_id'].toString();
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('firebase_uid', user.uid);
          await prefs.setString('db_user_id', _dbUserId!);
          _fetchUserData();
        }
      }
    }
  }

  Future<void> _initMusic() async {
    _audioPlayer = AudioPlayer();
    await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
    try {
      await _audioPlayer!.play(AssetSource('audio/bg_music.mp3'));
      setState(() {
        _isMusicPlaying = true;
      });
    } catch (e) {
      print("Error playing music: $e");
    }
  }

  Future<void> _toggleMusic() async {
    if (_audioPlayer != null) {
      if (_isMusicPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.resume();
      }
      setState(() {
        _isMusicPlaying = !_isMusicPlaying;
      });
    }
  }

  void _logoutUser(BuildContext context) async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    await _audioPlayer?.stop();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  Widget _buildGameModeCard(
      BuildContext context, String mode, String imageUrl, String gameId) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: InkWell(
        onTap: () {
          if (_dbUserId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please wait, user data is loading...')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MatchingScreen(userId: _dbUserId!, gameId: gameId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15.0),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15.0),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  mode,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black,
                        offset: Offset(2.0, 2.0),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(_profilePicture.isNotEmpty
                  ? _profilePicture
                  : 'https://img.freepik.com/free-vector/blue-circle-with-white-user_78370-4707.jpg'),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee,
                        size: 14, color: Colors.white),
                    Text(
                      '$_coins',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isMusicPlaying ? Icons.music_note : Icons.music_off,
              color: Colors.white,
            ),
            onPressed: _toggleMusic,
            tooltip: _isMusicPlaying ? 'Turn off music' : 'Turn on music',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            onPressed: () {
              if (_dbUserId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WalletScreen(userId: _dbUserId!),
                ),
              ).then((_) => _fetchUserData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              if (_dbUserId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddCoinScreen(userId: _dbUserId!),
                ),
              ).then((_) => _fetchUserData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              if (_dbUserId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                      // userId: _dbUserId!,
                      // onLogout: () => _logoutUser(context),
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              'https://as2.ftcdn.net/v2/jpg/00/63/76/09/1000_F_63760979_1JDPfVWqh8hQxeMvI2ZFrx6X7SPqAJB1.jpg',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Ludo Zone!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                if (_firebaseUid != null)
                  Text(
                    'Firebase UID: $_firebaseUid',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                if (_dbUserId != null)
                  Text(
                    'User ID: $_dbUserId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Join exciting Ludo games and win amazing prizes!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 30),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 0.9,
              children: [
                _buildGameModeCard(
                  context,
                  'Classic Ludo',
                  'https://as2.ftcdn.net/v2/jpg/01/94/11/85/1000_F_194118594_Gg3J4sZCVOqL4NLfovCGnNGvwC3669gD.jpg',
                  'classic',
                ),
                _buildGameModeCard(
                  context,
                  'Quick Ludo',
                  'https://as1.ftcdn.net/v2/jpg/09/02/55/02/1000_F_902550299_CQyS6Mv7ZlDW0Dl0Pigboa6eUyVQWqIz.jpg',
                  'quick',
                ),
                _buildGameModeCard(
                  context,
                  'Point Ludo',
                  'https://as1.ftcdn.net/v2/jpg/00/77/07/58/1000_F_77075862_RZ2szxgWPh5KqQcw6p80a1nDANyiiIMz.jpg',
                  'point',
                ),
                _buildGameModeCard(
                  context,
                  'Tournaments',
                  'https://as1.ftcdn.net/v2/jpg/02/24/90/58/1000_F_224905826_mnSb5a41hqx6gfmBE6iRDbC5Peu9Aoin.jpg',
                  'tournament',
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              onPressed: () => _logoutUser(context),
              child: const Text(
                'Logout',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: const Text(
          'For any issues, contact support@ludo.eventsystem.online',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }
}
