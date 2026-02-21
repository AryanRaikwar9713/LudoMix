import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:ludo_flutter/login.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'game/game_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Removed: auto Google sign-in on startup was forcing popup for phone/PIN users
  // User chooses login method (Phone/PIN or Google) on LoginPage

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => Ludo()..startGame()),
      // ChangeNotifierProvider(
      //     create: (_) => FourPlayerProvider()), // Add FourPlayerProvider
    ],
    child: const Root(),
  ));
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  @override
  void initState() {
    /// Initialize images and precache them
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.wait([
        precacheImage(const AssetImage("assets/images/thankyou.gif"), context),
        precacheImage(const AssetImage("assets/images/board.png"), context),
        precacheImage(const AssetImage("assets/images/dice/1.png"), context),
        precacheImage(const AssetImage("assets/images/dice/2.png"), context),
        precacheImage(const AssetImage("assets/images/dice/3.png"), context),
        precacheImage(const AssetImage("assets/images/dice/4.png"), context),
        precacheImage(const AssetImage("assets/images/dice/5.png"), context),
        precacheImage(const AssetImage("assets/images/dice/6.png"), context),
        precacheImage(const AssetImage("assets/images/dice/draw.gif"), context),
        precacheImage(const AssetImage("assets/images/crown/1st.png"), context),
        precacheImage(const AssetImage("assets/images/crown/2nd.png"), context),
        precacheImage(const AssetImage("assets/images/crown/3rd.png"), context),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ludo Game',
      theme: ThemeData(
        colorSchemeSeed: Colors.black,
        useMaterial3: true,
      ),
      home: LoginPage(), // Set LoginPage as the initial screen
    );
  }
}
