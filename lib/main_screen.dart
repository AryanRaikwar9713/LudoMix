// import 'package:flutter/material.dart';
// import 'package:ludo_flutter/ludo_provider.dart';
// import 'package:ludo_flutter/utils/const_res.dart';
// import 'package:ludo_flutter/widgets/board_widget.dart';
// import 'package:ludo_flutter/widgets/dice_widget.dart';
// import 'package:provider/provider.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
//
// import 'game/game.dart';
//
// class MainScreen extends StatefulWidget {
//   final String userId;
//   final String gameId;
//   final Map<String, dynamic> matchData;
//
//   const MainScreen({
//     Key? key,
//     required this.userId,
//     required this.gameId,
//     required this.matchData,
//   }) : super(key: key);
//
//   @override
//   State<MainScreen> createState() => _MainScreenState();
// }
//
// class _MainScreenState extends State<MainScreen> {
//   late String player1Name; // Logged-in user
//   late String player1Image; // Logged-in user
//   String? player2Name; // Opponent
//   String? player2Image; // Opponent
//   bool isLoading = true; // To track loading status
//
//   @override
//   void initState() {
//     super.initState();
//     // Initialize player data from matchData
//     player1Name = widget.matchData['loggedInUser']['name'] ?? 'Aryan Hammad';
//     player1Image = widget.matchData['loggedInUser']['profilePic'] ??
//         'https://img.freepik.com/free-vector/blue-circle-with-white-user_78370-4707.jpg';
//
//     // Fetch opponent data
//     _fetchOpponentData(widget.userId, widget.gameId);
//   }
//
//   Future<void> _fetchOpponentData(String userId, String gameId) async {
//     final url =
//         'https://ludo.eventsystem.online/api/board/opponend_data.php?user_id=$userId&game_id=$gameId';
//
//     try {
//       final response = await http.get(Uri.parse(url));
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//
//         if (data['success']) {
//           // Update opponent data with fetched data
//           setState(() {
//             player2Name = data['opponent']['name'];
//             player2Image =
//                 '${ConstRes.base}' + data['opponent']['profile_picture'];
//             isLoading = false; // Set loading to false on success
//           });
//         } else {
//           print(data['message']);
//           setState(() {
//             player2Name =
//                 'Opponent Player'; // Provide default in case of failure
//             player2Image =
//                 '${ConstRes.base}/storage/profile/profile.png'; // Default image
//             isLoading = false; // Set loading to false even on failure
//           });
//         }
//       } else {
//         print('Error: ${response.statusCode}');
//         setState(() {
//           player2Name = 'Opponent Player'; // Provide default
//           player2Image =
//               '${ConstRes.base}/storage/profile/profile.png'; // Default image
//           isLoading = false;
//         });
//       }
//     } catch (error) {
//       print('Failed to fetch opponent data: $error');
//       setState(() {
//         player2Name = 'Opponent Player'; // Provide default
//         player2Image =
//             '${ConstRes.base}/storage/profile/profile.png'; // Default image
//         isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return const Center(
//           child:
//               CircularProgressIndicator()); // Show loading indicator while fetching
//     }
//
//     return Scaffold(
//       backgroundColor: Colors.purple.withOpacity(0.9),
//       body: Stack(
//         children: [
//           // Main game board
//           Column(
//             mainAxisAlignment: MainAxisAlignment.start,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Expanded(
//                 child: Center(
//                   child: BoardWidget(),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Center(
//                 child: Container(
//                   width: 60,
//                   height: 60,
//                   decoration: const BoxDecoration(
//                     color: Colors.white,
//                   ),
//                   child: DiceWidget(),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Consumer<LudoProvider>(
//                 builder: (context, value, child) {
//                   if (value.winners.length == 3) {
//                     return Container(
//                       color: Colors.black.withOpacity(0.8),
//                       padding: const EdgeInsets.all(20),
//                       child: Center(
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Image.asset("assets/images/thankyou.gif"),
//                             const Text(
//                               "Thank you for playing 😙",
//                               style:
//                                   TextStyle(color: Colors.white, fontSize: 20),
//                               textAlign: TextAlign.center,
//                             ),
//                             Text(
//                               "The Winners are: ${value.winners.map((e) => e.name.toUpperCase()).join(", ")}",
//                               style: const TextStyle(
//                                   color: Colors.white, fontSize: 30),
//                               textAlign: TextAlign.center,
//                             ),
//                             const Divider(color: Colors.white),
//                             const Text(
//                               "This game was made with Flutter ❤ by Mochamad Aryan Raikwar",
//                               style:
//                                   TextStyle(color: Colors.white, fontSize: 15),
//                               textAlign: TextAlign.center,
//                             ),
//                             const SizedBox(height: 20),
//                             const Text(
//                               "Refresh your browser to play again",
//                               style:
//                                   TextStyle(color: Colors.white, fontSize: 10),
//                               textAlign: TextAlign.center,
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   }
//                   return const SizedBox.shrink(); // No winners yet
//                 },
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//
//           // User profile sections
//           Positioned(
//             bottom: 10,
//             left: 10,
//             child:
//                 _buildUserProfile(player1Name, player1Image), // Logged-in user
//           ),
//           Positioned(
//             top: 10,
//             right: 10,
//             child: _buildUserProfile(player2Name!, player2Image!), // Opponent
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildUserProfile(String username, String imageUrl) {
//     return GestureDetector(
//       onTap: () {
//         _showUserProfileDialog(username, imageUrl);
//       },
//       child: Container(
//         width: 120,
//         decoration: BoxDecoration(
//           color: Colors.grey[500],
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(color: Colors.grey.shade600, width: 1),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.5),
//               blurRadius: 15,
//               offset: const Offset(0, 5),
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircleAvatar(
//               radius: 30,
//               backgroundImage: NetworkImage(imageUrl),
//               backgroundColor: Colors.blueAccent,
//             ),
//             const SizedBox(height: 4),
//             Text(
//               username,
//               style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 12),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.mic, size: 18, color: Colors.white),
//                   onPressed: () {},
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.volume_up,
//                       size: 18, color: Colors.white),
//                   onPressed: () {},
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showUserProfileDialog(String username, String imageUrl) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.white.withOpacity(0.9),
//           title: Text("Profile of $username"),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               CircleAvatar(
//                 radius: 40,
//                 backgroundImage: NetworkImage(imageUrl),
//                 backgroundColor: Colors.blueAccent,
//               ),
//               const SizedBox(height: 10),
//               Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
//               const SizedBox(height: 10),
//               TextButton(
//                 onPressed: () {},
//                 child: const Text("Add Friend"),
//               ),
//               const Text("Send a Gift"),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.card_giftcard),
//                     onPressed: () {},
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.stars),
//                     onPressed: () {},
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.message),
//                     onPressed: () {},
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: const Text("Close"),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
