// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:ludo_flutter/ludo_player.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'audio.dart';
// import 'constants.dart';
// import 'game/game_data.dart';
//
// class LudoProvider extends ChangeNotifier {
//   // Existing properties
//   bool _isMoving = false;
//   bool _stopMoving = false;
//   LudoGameState _gameState = LudoGameState.throwDice;
//   LudoPlayerType _currentTurn = LudoPlayerType.green;
//   int _diceResult = 0;
//   bool _diceStarted = false;
//   final List<LudoPlayer> players = [];
//   final List<LudoPlayerType> winners = [];
//
//   // Firebase related properties
//   late DatabaseReference _gameRef;
//   late StreamSubscription _gameSubscription;
//   bool _isOnlineGame = false;
//   LudoPlayerType? _localPlayerType;
//   Timer? _turnTimer;
//
//   // Getters
//   LudoGameState get gameState => _gameState;
//   int get diceResult => _diceResult.clamp(1, 6);
//   bool get diceStarted => _diceStarted;
//   LudoPlayer get currentPlayer =>
//       players.firstWhere((element) => element.type == _currentTurn);
//   bool get isMyTurn => _isOnlineGame ? _currentTurn == _localPlayerType : true;
//
//   // Initialize Firebase
//   void initializeOnlineGame() {
//     if (GameData.gameId == null ||
//         GameData.loggedInUserId == null ||
//         GameData.opponentId == null) {
//       return;
//     }
//
//     _isOnlineGame = true;
//     _gameRef = FirebaseDatabase.instance.ref('games/${GameData.gameId}');
//
//     // Determine local player type (assuming 2-player game for simplicity)
//     if (GameData.loggedInUserId!.compareTo(GameData.opponentId!) < 0) {
//       _localPlayerType = LudoPlayerType.green;
//     } else {
//       _localPlayerType = LudoPlayerType.blue;
//     }
//
//     // Listen for game updates
//     _gameSubscription = _gameRef.onValue.listen((event) {
//       if (event.snapshot.value == null) return;
//
//       final data = event.snapshot.value as Map<dynamic, dynamic>;
//       _syncGameState(data);
//     });
//
//     // Initialize game in Firebase if not exists
//     _gameRef.once().then((snapshot) {
//       if (snapshot.snapshot.value == null) {
//         _saveGameState();
//       }
//     });
//   }
//
//   // Sync game state from Firebase
//   void _syncGameState(Map<dynamic, dynamic> data) {
//     // Don't process our own updates
//     if (data['lastUpdatedBy'] == GameData.loggedInUserId) return;
//
//     // Update game state
//     _currentTurn = LudoPlayerType.values
//         .firstWhere((e) => e.toString() == data['currentTurn']);
//     _diceResult = data['diceResult'] ?? 0;
//     _gameState = LudoGameState.values
//         .firstWhere((e) => e.toString() == data['gameState']);
//
//     // Update players
//     for (var playerData in data['players']) {
//       final player =
//           players.firstWhere((p) => p.type.toString() == playerData['type']);
//       player.updateFromMap(playerData);
//     }
//
//     // Update winners
//     winners.clear();
//     for (var winner in data['winners']) {
//       winners
//           .add(LudoPlayerType.values.firstWhere((e) => e.toString() == winner));
//     }
//
//     notifyListeners();
//
//     // Start turn timer if it's our turn
//     if (isMyTurn) {
//       _startTurnTimer();
//     }
//   }
//
//   // Save current game state to Firebase
//   void _saveGameState() {
//     if (!_isOnlineGame) return;
//
//     final gameData = {
//       'currentTurn': _currentTurn.toString(),
//       'diceResult': _diceResult,
//       'gameState': _gameState.toString(),
//       'players': players.map((player) => player.toMap()).toList(),
//       'winners': winners.map((winner) => winner.toString()).toList(),
//       'lastUpdated': ServerValue.timestamp,
//       'lastUpdatedBy': GameData.loggedInUserId,
//     };
//
//     _gameRef.update(gameData);
//   }
//
//   // Start turn timer (10 seconds per turn)
//   void _startTurnTimer() {
//     _turnTimer?.cancel();
//     _turnTimer = Timer(const Duration(seconds: 10), () {
//       if (isMyTurn && _gameState != LudoGameState.moving) {
//         nextTurn();
//       }
//     });
//   }
//
//   // Modified throwDice for online play
//   void throwDice() async {
//     if (_gameState != LudoGameState.throwDice || !isMyTurn) return;
//
//     _diceStarted = true;
//     notifyListeners();
//     Audio.rollDice();
//
//     if (winners.contains(currentPlayer.type)) {
//       nextTurn();
//       return;
//     }
//
//     currentPlayer.highlightAllPawns(false);
//
//     Future.delayed(const Duration(seconds: 1)).then((value) {
//       _diceStarted = false;
//       var random = Random();
//       _diceResult = random.nextBool() ? 6 : random.nextInt(6) + 1;
//
//       // For online game, save to Firebase
//       if (_isOnlineGame) {
//         _gameState = LudoGameState.throwDice; // Temporary state
//         _saveGameState();
//
//         // Process the dice result after saving
//         _processDiceResult();
//       } else {
//         _processDiceResult();
//         notifyListeners();
//       }
//     });
//   }
//
//   void _processDiceResult() {
//     if (diceResult == 6) {
//       currentPlayer.highlightAllPawns();
//       _gameState = LudoGameState.pickPawn;
//     } else {
//       if (currentPlayer.pawnInsideCount == 4) {
//         nextTurn();
//         return;
//       } else {
//         currentPlayer.highlightOutside();
//         _gameState = LudoGameState.pickPawn;
//       }
//     }
//
//     for (var i = 0; i < currentPlayer.pawns.length; i++) {
//       var pawn = currentPlayer.pawns[i];
//       if ((pawn.step + diceResult) > currentPlayer.path.length - 1) {
//         currentPlayer.highlightPawn(i, false);
//       }
//     }
//
//     var moveablePawn = currentPlayer.pawns.where((e) => e.highlight).toList();
//     if (moveablePawn.length > 1) {
//       var biggestStep = moveablePawn.map((e) => e.step).reduce(max);
//       if (moveablePawn.every((element) => element.step == biggestStep)) {
//         var random = 1 + Random().nextInt(moveablePawn.length - 1);
//         if (moveablePawn[random].step == -1) {
//           var thePawn = moveablePawn[random];
//           move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
//           return;
//         } else {
//           var thePawn = moveablePawn[random];
//           move(thePawn.type, thePawn.index, (thePawn.step + 1) + diceResult);
//           return;
//         }
//       }
//     }
//
//     if (currentPlayer.pawns.every((element) => !element.highlight)) {
//       if (diceResult == 6) {
//         _gameState = LudoGameState.throwDice;
//       } else {
//         nextTurn();
//         return;
//       }
//     }
//
//     if (currentPlayer.pawns.where((element) => element.highlight).length == 1) {
//       var index =
//           currentPlayer.pawns.indexWhere((element) => element.highlight);
//       move(currentPlayer.type, index,
//           (currentPlayer.pawns[index].step + 1) + diceResult);
//     }
//
//     if (_isOnlineGame) {
//       _saveGameState();
//     }
//   }
//
//   // Modified move for online play
//   void move(LudoPlayerType type, int index, int step) async {
//     if (_isMoving || !isMyTurn) return;
//     _isMoving = true;
//     _gameState = LudoGameState.moving;
//
//     currentPlayer.highlightAllPawns(false);
//
//     var selectedPlayer = player(type);
//     for (int i = selectedPlayer.pawns[index].step; i < step; i++) {
//       if (_stopMoving) break;
//       if (selectedPlayer.pawns[index].step == i) continue;
//       selectedPlayer.movePawn(index, i);
//       await Audio.playMove();
//       if (_isOnlineGame) {
//         _saveGameState();
//       } else {
//         notifyListeners();
//       }
//       if (_stopMoving) break;
//     }
//
//     if (checkToKill(type, index, step, selectedPlayer.path)) {
//       _gameState = LudoGameState.throwDice;
//       _isMoving = false;
//       Audio.playKill();
//       if (_isOnlineGame) {
//         _saveGameState();
//       } else {
//         notifyListeners();
//       }
//       return;
//     }
//
//     validateWin(type);
//
//     if (diceResult == 6) {
//       _gameState = LudoGameState.throwDice;
//     } else {
//       nextTurn();
//     }
//
//     _isMoving = false;
//     if (_isOnlineGame) {
//       _saveGameState();
//     } else {
//       notifyListeners();
//     }
//   }
//
//   // Modified nextTurn for online play
//   void nextTurn() {
//     switch (_currentTurn) {
//       case LudoPlayerType.green:
//         _currentTurn = LudoPlayerType.yellow;
//         break;
//       case LudoPlayerType.yellow:
//         _currentTurn = LudoPlayerType.blue;
//         break;
//       case LudoPlayerType.blue:
//         _currentTurn = LudoPlayerType.red;
//         break;
//       case LudoPlayerType.red:
//         _currentTurn = LudoPlayerType.green;
//         break;
//     }
//
//     if (winners.contains(_currentTurn)) return nextTurn();
//     _gameState = LudoGameState.throwDice;
//
//     if (_isOnlineGame) {
//       _startTurnTimer();
//       _saveGameState();
//     } else {
//       notifyListeners();
//     }
//   }
//
//   // Existing methods remain the same...
//   LudoPlayer player(LudoPlayerType type) =>
//       players.firstWhere((element) => element.type == type);
//
//   bool checkToKill(
//       LudoPlayerType type, int index, int step, List<List<double>> path) {
//     bool killSomeone = false;
//     for (int i = 0; i < 4; i++) {
//       var greenElement = player(LudoPlayerType.green).pawns[i];
//       var blueElement = player(LudoPlayerType.blue).pawns[i];
//       var redElement = player(LudoPlayerType.red).pawns[i];
//       var yellowElement = player(LudoPlayerType.yellow).pawns[i];
//
//       if ((greenElement.step > -1 &&
//               !LudoPath.safeArea.map((e) => e.toString()).contains(
//                   player(LudoPlayerType.green)
//                       .path[greenElement.step]
//                       .toString())) &&
//           type != LudoPlayerType.green) {
//         if (player(LudoPlayerType.green).path[greenElement.step].toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.green).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//       if ((yellowElement.step > -1 &&
//               !LudoPath.safeArea.map((e) => e.toString()).contains(
//                   player(LudoPlayerType.yellow)
//                       .path[yellowElement.step]
//                       .toString())) &&
//           type != LudoPlayerType.yellow) {
//         if (player(LudoPlayerType.yellow).path[yellowElement.step].toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.yellow).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//       if ((blueElement.step > -1 &&
//               !LudoPath.safeArea.map((e) => e.toString()).contains(
//                   player(LudoPlayerType.blue)
//                       .path[blueElement.step]
//                       .toString())) &&
//           type != LudoPlayerType.blue) {
//         if (player(LudoPlayerType.blue).path[blueElement.step].toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.blue).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//       if ((redElement.step > -1 &&
//               !LudoPath.safeArea.map((e) => e.toString()).contains(
//                   player(LudoPlayerType.red)
//                       .path[redElement.step]
//                       .toString())) &&
//           type != LudoPlayerType.red) {
//         if (player(LudoPlayerType.red).path[redElement.step].toString() ==
//             path[step - 1].toString()) {
//           killSomeone = true;
//           player(LudoPlayerType.red).movePawn(i, -1);
//           notifyListeners();
//         }
//       }
//     }
//     return killSomeone;
//   }
//
//   void validateWin(LudoPlayerType color) {/* same as before */}
//
//   void startGame() {
//     winners.clear();
//     players.clear();
//     players.addAll([
//       LudoPlayer(LudoPlayerType.green),
//       LudoPlayer(LudoPlayerType.yellow),
//       LudoPlayer(LudoPlayerType.blue),
//       LudoPlayer(LudoPlayerType.red),
//     ]);
//
//     if (GameData.gameId != null) {
//       initializeOnlineGame();
//     }
//   }
//
//   @override
//   void dispose() {
//     _stopMoving = true;
//     _turnTimer?.cancel();
//     _gameSubscription.cancel();
//     super.dispose();
//   }
//
//   static LudoProvider read(BuildContext context) => context.read();
// }
