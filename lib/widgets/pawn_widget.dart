// import 'package:flutter/material.dart';
// import 'package:ludo_flutter/constants.dart';
// import 'package:ludo_flutter/ludo_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:simple_ripple_animation/simple_ripple_animation.dart';
//
// class PawnWidget extends StatelessWidget {
//   final int index;
//   final LudoPlayerType type;
//   final int step;
//   final bool highlight;
//
//   const PawnWidget(this.index, this.type,
//       {super.key, this.highlight = false, this.step = -1});
//
//   // Firebase के लिए नया method
//   Map<String, dynamic> toMap() {
//     return {
//       'index': index,
//       'type': type.toString(),
//       'step': step,
//       'highlight': highlight,
//     };
//   }
//
//   // Firebase से डेटा update करने के लिए नया method
//   PawnWidget updateFromMap(Map<dynamic, dynamic> data) {
//     return PawnWidget(
//       data['index'] ?? index,
//       LudoPlayerType.values.firstWhere((e) => e.toString() == data['type']),
//       step: data['step'] ?? step,
//       highlight: data['highlight'] ?? highlight,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // ... आपका existing build method वैसा का वैसा ही रहता है ...
//     Color color = Colors.white;
//     switch (type) {
//       case LudoPlayerType.green:
//         color = LudoColor.green;
//         break;
//       case LudoPlayerType.yellow:
//         color = LudoColor.yellow;
//         break;
//       case LudoPlayerType.blue:
//         color = LudoColor.blue;
//         break;
//       case LudoPlayerType.red:
//         color = LudoColor.red;
//         break;
//     }
//     return IgnorePointer(
//       ignoring: !highlight,
//       child: Stack(
//         alignment: Alignment.center,
//         children: [
//           if (highlight)
//             RippleAnimation(
//               color: color,
//               minRadius: 20,
//               repeat: true,
//               ripplesCount: 3,
//               child: const SizedBox.shrink(),
//             ),
//           Consumer<LudoProvider>(
//             builder: (context, provider, child) => GestureDetector(
//               onTap: () {
//                 if (step == -1) {
//                   provider.move(type, index, (step + 1) + 1);
//                 } else {
//                   provider.move(type, index, (step + 1) + provider.diceResult);
//                 }
//                 context.read<LudoProvider>().move(type, index, step);
//               },
//               child: Container(
//                 decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     border: Border.all(color: color, width: 2)),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: color,
//                     shape: BoxShape.circle,
//                     border: Border.all(color: Colors.white, width: 2),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
