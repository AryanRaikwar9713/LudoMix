// import 'package:flutter/material.dart';
// import 'package:ludo_flutter/constants.dart';
// import 'package:ludo_flutter/ludo_provider.dart';
// import 'package:ludo_flutter/widgets/pawn_widget.dart';
// import 'package:provider/provider.dart';
//
// import '../ludo_player.dart';
//
// ///Widget for the board
// class BoardWidget extends StatelessWidget {
//   const BoardWidget({super.key});
//
//   ///Return board size
//   double ludoBoard(BuildContext context) {
//     double width = MediaQuery.of(context).size.width;
//     if (width > 500) {
//       return 500;
//     } else {
//       if (width < 300) {
//         return 300;
//       } else {
//         return width - 20;
//       }
//     }
//   }
//
//   ///Count box size
//   double boxStepSize(BuildContext context) {
//     return ludoBoard(context) / 15;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Container(
//           margin: const EdgeInsets.all(10),
//           clipBehavior: Clip.antiAlias,
//           width: ludoBoard(context),
//           height: ludoBoard(context),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(40),
//             image: const DecorationImage(
//               image: AssetImage("assets/images/board.png"),
//               fit: BoxFit.cover,
//               alignment: Alignment.topCenter,
//             ),
//           ),
//           child: Consumer<LudoProvider>(
//             builder: (context, value, child) {
//               List<LudoPlayer> players = List.from(value.players);
//               Map<String, List<PawnWidget>> pawnsRaw = {};
//               Map<String, List<String>> pawnsToPrint = {};
//               List<Widget> playersPawn = [];
//
//               // Sort players by current turn
//               players
//                   .sort((a, b) => value.currentPlayer.type == a.type ? 1 : -1);
//
//               // Build list of pawns
//               for (int i = 0; i < players.length; i++) {
//                 var player = players[i];
//                 for (int j = 0; j < player.pawns.length; j++) {
//                   var pawn = player.pawns[j];
//                   if (pawn.step > -1) {
//                     String step = player.path[pawn.step].toString();
//                     if (pawnsRaw[step] == null) {
//                       pawnsRaw[step] = [];
//                       pawnsToPrint[step] = [];
//                     }
//                     pawnsRaw[step]!.add(pawn);
//                     pawnsToPrint[step]!.add(player.type.toString());
//                   } else {
//                     if (pawnsRaw["home"] == null) {
//                       pawnsRaw["home"] = [];
//                       pawnsToPrint["home"] = [];
//                     }
//                     pawnsRaw["home"]!.add(pawn);
//                     pawnsToPrint["home"]!.add(player.type.toString());
//                   }
//                 }
//               }
//
//               // Loop to create pawn widgets
//               for (String key in pawnsRaw.keys) {
//                 List<PawnWidget> pawnsValue = pawnsRaw[key]!;
//                 if (key == "home") {
//                   playersPawn.addAll(
//                     pawnsValue.map((e) {
//                       var player = value.players
//                           .firstWhere((element) => element.type == e.type);
//                       return AnimatedPositioned(
//                         key: ValueKey("${e.type.name}_${e.index}"),
//                         left: LudoPath.stepBox(
//                             ludoBoard(context), player.homePath[e.index][0]),
//                         top: LudoPath.stepBox(
//                             ludoBoard(context), player.homePath[e.index][1]),
//                         width: boxStepSize(context),
//                         height: boxStepSize(context),
//                         duration: const Duration(milliseconds: 200),
//                         child: e,
//                       );
//                     }),
//                   );
//                 } else {
//                   List<double> coordinates = key
//                       .replaceAll("[", "")
//                       .replaceAll("]", "")
//                       .split(",")
//                       .map((e) => double.parse(e.trim()))
//                       .toList();
//                   if (pawnsValue.length == 1) {
//                     // For 1 pawn in 1 box
//                     var e = pawnsValue.first;
//                     playersPawn.add(AnimatedPositioned(
//                       key: ValueKey("${e.type.name}_${e.index}"),
//                       duration: const Duration(milliseconds: 200),
//                       left:
//                           LudoPath.stepBox(ludoBoard(context), coordinates[0]),
//                       top: LudoPath.stepBox(ludoBoard(context), coordinates[1]),
//                       width: boxStepSize(context),
//                       height: boxStepSize(context),
//                       child: pawnsValue.first,
//                     ));
//                   } else {
//                     // For more than 1 pawn in 1 box
//                     playersPawn.addAll(
//                       List.generate(
//                         pawnsValue.length,
//                         (index) {
//                           var e = pawnsValue[index];
//                           return AnimatedPositioned(
//                             key: ValueKey("${e.type.name}_${e.index}"),
//                             duration: const Duration(milliseconds: 200),
//                             left: LudoPath.stepBox(
//                                     ludoBoard(context), coordinates[0]) +
//                                 (index * 3),
//                             top: LudoPath.stepBox(
//                                 ludoBoard(context), coordinates[1]),
//                             width: boxStepSize(context) - 5,
//                             height: boxStepSize(context),
//                             child: pawnsValue[index],
//                           );
//                         },
//                       ),
//                     );
//                   }
//                 }
//               }
//
//               // Build and return Center widget
//               return Center(
//                 child: Stack(
//                   fit: StackFit.expand,
//                   alignment: Alignment.center,
//                   children: [
//                     ...playersPawn,
//                     ...winners(context, value.winners),
//                     turnIndicator(context, value.currentPlayer.type,
//                         value.currentPlayer.color, value.gameState),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   // Turn indicator widget
//   Widget turnIndicator(BuildContext context, LudoPlayerType turn, Color color,
//       LudoGameState stage) {
//     int x = 0;
//     int y = 0;
//
//     switch (turn) {
//       case LudoPlayerType.green:
//         x = 0;
//         y = 0;
//         break;
//       case LudoPlayerType.yellow:
//         x = 1;
//         y = 0;
//         break;
//       case LudoPlayerType.blue:
//         x = 1;
//         y = 1;
//         break;
//       case LudoPlayerType.red:
//         x = 0;
//         y = 1;
//         break;
//     }
//
//     String stageText = "Roll the dice";
//     switch (stage) {
//       case LudoGameState.throwDice:
//         stageText = "Roll the dice";
//         break;
//       case LudoGameState.moving:
//         stageText = "Pawn is moving...";
//         break;
//       case LudoGameState.pickPawn:
//         stageText = "Pick a pawn";
//         break;
//       case LudoGameState.finish:
//         stageText = "Game is over";
//         break;
//     }
//
//     return Positioned(
//       top: y == 0 ? 0 : null,
//       left: x == 0 ? 0 : null,
//       right: x == 1 ? 0 : null,
//       bottom: y == 1 ? 0 : null,
//       width: ludoBoard(context) * .4,
//       height: ludoBoard(context) * .4,
//       child: IgnorePointer(
//         child: Padding(
//           padding: EdgeInsets.all(boxStepSize(context)),
//           child: Container(
//               alignment: Alignment.center,
//               clipBehavior: Clip.antiAlias,
//               decoration:
//                   BoxDecoration(borderRadius: BorderRadius.circular(15)),
//               child: RichText(
//                 textAlign: TextAlign.center,
//                 text: TextSpan(
//                     style: TextStyle(fontSize: 8, color: color),
//                     children: [
//                       const TextSpan(
//                           text: "Your turn!\n",
//                           style: TextStyle(
//                               fontSize: 12, fontWeight: FontWeight.bold)),
//                       TextSpan(
//                           text: stageText,
//                           style: const TextStyle(color: Colors.black)),
//                     ]),
//               )),
//         ),
//       ),
//     );
//   }
//
//   // Winner widget
//   List<Widget> winners(BuildContext context, List<LudoPlayerType> winners) =>
//       List.generate(
//         winners.length,
//         (index) {
//           Widget crownImage;
//           if (index == 0) {
//             crownImage =
//                 Image.asset("assets/images/crown/1st.png", fit: BoxFit.cover);
//           } else if (index == 1) {
//             crownImage =
//                 Image.asset("assets/images/crown/2nd.png", fit: BoxFit.cover);
//           } else if (index == 2) {
//             crownImage =
//                 Image.asset("assets/images/crown/3rd.png", fit: BoxFit.cover);
//           } else {
//             return Container();
//           }
//
//           int x = 0;
//           int y = 0;
//
//           switch (winners[index]) {
//             case LudoPlayerType.green:
//               x = 0;
//               y = 0;
//               break;
//             case LudoPlayerType.yellow:
//               x = 1;
//               y = 0;
//               break;
//             case LudoPlayerType.blue:
//               x = 1;
//               y = 1;
//               break;
//             case LudoPlayerType.red:
//               x = 0;
//               y = 1;
//               break;
//           }
//
//           return Positioned(
//             top: y == 0 ? 0 : null,
//             left: x == 0 ? 0 : null,
//             right: x == 1 ? 0 : null,
//             bottom: y == 1 ? 0 : null,
//             width: ludoBoard(context) * .4,
//             height: ludoBoard(context) * .4,
//             child: Padding(
//               padding: EdgeInsets.all(boxStepSize(context)),
//               child: Container(
//                 clipBehavior: Clip.antiAlias,
//                 decoration:
//                     BoxDecoration(borderRadius: BorderRadius.circular(15)),
//                 child: crownImage,
//               ),
//             ),
//           );
//         },
//       );
// }
