import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:provider/provider.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';
import 'dart:async';
import 'dart:math';

import '../audio.dart';


class PawnWidget2v2 extends StatelessWidget {
  final int index;
  final LudoPlayerType type;
  final int step;
  final bool highlight;

  const PawnWidget2v2(this.index, this.type,
      {super.key, this.highlight = false, this.step = -1});

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'type': type.toString(),
      'step': step,
      'highlight': highlight,
    };
  }

  PawnWidget2v2 updateFromMap(Map<dynamic, dynamic> data) {
    return PawnWidget2v2(
      data['index'] ?? index,
      LudoPlayerType.values.firstWhere((e) => e.toString() == data['type']),
      step: data['step'] ?? step,
      highlight: data['highlight'] ?? highlight,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Color choose based on player type, with special handling for 2-player mode:
    // In 2v2 we want the second player visually BLUE instead of RED.
    return Consumer<Ludo2v2>(
      builder: (context, provider, child) {
        Color color = Colors.white;
        switch (type) {
          case LudoPlayerType.green:
            color = LudoColor.green;
            break;
          case LudoPlayerType.yellow:
            color = LudoColor.yellow;
            break;
          case LudoPlayerType.blue:
            color = LudoColor.blue;
            break;
          case LudoPlayerType.red:
            // If only 2 players, paint RED player as BLUE visually.
            color = provider.playerCount == 2 ? LudoColor.blue : LudoColor.red;
            break;
        }

        // Do NOT block taps based only on highlight; legality is enforced in provider.move().
        return Stack(
          alignment: Alignment.center,
          children: [
            if (highlight)
              RippleAnimation(
                color: color.withOpacity(0.7),
                minRadius: 12, // smaller ripple
                repeat: true,
                ripplesCount: 2,
                child: const SizedBox.shrink(),
              ),
            GestureDetector(
              onTap: () {
                // Actual rules & turn checks are inside provider.move().
                if (step == -1) {
                  provider.move(type, index, (step + 1) + 1);
                } else {
                  provider.move(
                      type, index, (step + 1) + provider.diceResult);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class LudoPlayer2v2 {
  final LudoPlayerType type;
  late List<List<double>> path;
  late List<List<double>> homePath;
  final List<PawnWidget2v2> pawns = [];
  late Color color;

  LudoPlayer2v2(this.type) {
    for (int i = 0; i < 4; i++) {
      pawns.add(PawnWidget2v2(i, type));
    }

    switch (type) {
      case LudoPlayerType.green:
        path = LudoPath.greenPath;
        color = LudoColor.green;
        homePath = LudoPath.greenHomePath;
        break;
      case LudoPlayerType.yellow:
        path = LudoPath.yellowPath;
        color = LudoColor.yellow;
        homePath = LudoPath.yellowHomePath;
        break;
      case LudoPlayerType.blue:
        path = LudoPath.bluePath;
        color = LudoColor.blue;
        homePath = LudoPath.blueHomePath;
        break;
      case LudoPlayerType.red:
        path = LudoPath.redPath;
        color = LudoColor.red;
        homePath = LudoPath.redHomePath;
        break;
    }
  }

  int get pawnInsideCount =>
      pawns.where((element) => element.step == -1).length;

  int get pawnOutsideCount =>
      pawns.where((element) => element.step > -1).length;

  void movePawn(int index, int step) async {
    pawns[index] = PawnWidget2v2(index, type, step: step, highlight: false);
  }

  void highlightPawn(int index, [bool highlight = true]) {
    var pawn = pawns[index];
    pawns.removeAt(index);
    pawns.insert(
      index,
      PawnWidget2v2(
        index,
        pawn.type,
        highlight: highlight,
        step: pawn.step,
      ),
    );
  }

  void highlightAllPawns([bool highlight = true]) {
    for (var i = 0; i < pawns.length; i++) {
      highlightPawn(i, highlight);
    }
  }

  void highlightOutside([bool highlight = true]) {
    for (var i = 0; i < pawns.length; i++) {
      if (pawns[i].step != -1) highlightPawn(i, highlight);
    }
  }

  void highlightInside([bool highlight = true]) {
    for (var i = 0; i < pawns.length; i++) {
      if (pawns[i].step == -1) highlightPawn(i, highlight);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'pawns': pawns.map((pawn) => pawn.toMap()).toList(),
    };
  }

  void updateFromMap(Map<dynamic, dynamic> data) {
    final pawnsData = data['pawns'];
    if (pawnsData == null) return;
    final list = pawnsData is List ? pawnsData : pawnsData.values.toList();
    for (int i = 0; i < pawns.length && i < list.length; i++) {
      final m = list[i] is Map
          ? Map<dynamic, dynamic>.from(list[i] as Map)
          : <dynamic, dynamic>{};
      pawns[i] = pawns[i].updateFromMap(m);
    }
  }
}

class Ludo2v2 extends ChangeNotifier {
  bool _isMoving = false;
  bool _stopMoving = false;
  // Remote animation flag (only for animating opponent moves from Firebase)
  bool _isRemoteAnimating = false;
  LudoGameState _gameState = LudoGameState.throwDice;
  LudoGameState get gameState => _gameState;
  LudoPlayerType _currentTurn = LudoPlayerType.green;
  int _diceResult = 0;

  // Online multiplayer - Firebase real-time sync
  String? _matchId;
  String? _userId;
  LudoPlayerType? _myColor;
  DatabaseReference? _matchRef;
  StreamSubscription<DatabaseEvent>? _gameSubscription;
  bool get isOnlineGame => _matchId != null && _userId != null;
  bool get isMyTurn => !isOnlineGame || _currentTurn == _myColor;

  // Track offline players
  Set<LudoPlayerType>? _offlinePlayers;
  Set<LudoPlayerType> get offlinePlayers {
    // Ensure _offlinePlayers is always initialized (handle JS undefined case)
    _offlinePlayers ??= <LudoPlayerType>{};
    return _offlinePlayers!;
  }

  /// Current user's pawn color (online: set from match; offline: null).
  LudoPlayerType? get myColor => _myColor;

  // Track previous pawn steps for animated remote movement
  Map<String, int> _previousPawnSteps = {};

  // Track consecutive sixes for current turn (rule: max 2 times, 3rd six loses turn)
  int _consecutiveSixCount = 0;

  int get diceResult {
    if (_diceResult < 1) {
      return 1;
    } else {
      if (_diceResult > 6) {
        return 6;
      } else {
        return _diceResult;
      }
    }
  }

  bool _diceStarted = false;
  bool get diceStarted => _diceStarted;
  LudoPlayer2v2 get currentPlayer =>
      players.firstWhere((element) => element.type == _currentTurn);
  final List<LudoPlayer2v2> players = [];
  final List<LudoPlayerType> winners = [];

  LudoPlayer2v2 player(LudoPlayerType type) =>
      players.firstWhere((element) => element.type == type);

  bool checkToKill(
      LudoPlayerType type, int index, int step, List<List<double>> path) {
    bool killSomeone = false;

    // For 2v2 mode: only check Green vs Blue
    // For 4v4 mode: check all players
    final is2v2 = _playerCount == 2;

    for (int i = 0; i < 4; i++) {
      // 2v2: Green vs Blue
      if (is2v2) {
        var greenElement = player(LudoPlayerType.green).pawns[i];
        var blueElement = player(LudoPlayerType.blue).pawns[i];

        // Check Green pawns (only if current player is Blue)
        if ((greenElement.step > -1 &&
                !LudoPath.safeArea.map((e) => e.toString()).contains(
                    player(LudoPlayerType.green)
                        .path[greenElement.step]
                        .toString())) &&
            type != LudoPlayerType.green) {
          if (player(LudoPlayerType.green).path[greenElement.step].toString() ==
              path[step - 1].toString()) {
            killSomeone = true;
            player(LudoPlayerType.green).movePawn(i, -1);
            notifyListeners();
          }
        }

        // Check Blue pawns (only if current player is Green)
        if ((blueElement.step > -1 &&
                !LudoPath.safeArea.map((e) => e.toString()).contains(
                    player(LudoPlayerType.blue)
                        .path[blueElement.step]
                        .toString())) &&
            type != LudoPlayerType.blue) {
          if (player(LudoPlayerType.blue).path[blueElement.step].toString() ==
              path[step - 1].toString()) {
            killSomeone = true;
            player(LudoPlayerType.blue).movePawn(i, -1);
            notifyListeners();
          }
        }
      } else {
        // 4v4 mode: check all players
        var greenElement = player(LudoPlayerType.green).pawns[i];
        var blueElement = player(LudoPlayerType.blue).pawns[i];
        var redElement = player(LudoPlayerType.red).pawns[i];
        var yellowElement = player(LudoPlayerType.yellow).pawns[i];

        if ((greenElement.step > -1 &&
                !LudoPath.safeArea.map((e) => e.toString()).contains(
                    player(LudoPlayerType.green)
                        .path[greenElement.step]
                        .toString())) &&
            type != LudoPlayerType.green) {
          if (player(LudoPlayerType.green).path[greenElement.step].toString() ==
              path[step - 1].toString()) {
            killSomeone = true;
            player(LudoPlayerType.green).movePawn(i, -1);
            notifyListeners();
          }
        }
        if ((yellowElement.step > -1 &&
                !LudoPath.safeArea.map((e) => e.toString()).contains(
                    player(LudoPlayerType.yellow)
                        .path[yellowElement.step]
                        .toString())) &&
            type != LudoPlayerType.yellow) {
          if (player(LudoPlayerType.yellow)
                  .path[yellowElement.step]
                  .toString() ==
              path[step - 1].toString()) {
            killSomeone = true;
            player(LudoPlayerType.yellow).movePawn(i, -1);
            notifyListeners();
          }
        }
        if ((blueElement.step > -1 &&
                !LudoPath.safeArea.map((e) => e.toString()).contains(
                    player(LudoPlayerType.blue)
                        .path[blueElement.step]
                        .toString())) &&
            type != LudoPlayerType.blue) {
          if (player(LudoPlayerType.blue).path[blueElement.step].toString() ==
              path[step - 1].toString()) {
            killSomeone = true;
            player(LudoPlayerType.blue).movePawn(i, -1);
            notifyListeners();
          }
        }
        if ((redElement.step > -1 &&
                !LudoPath.safeArea.map((e) => e.toString()).contains(
                    player(LudoPlayerType.red)
                        .path[redElement.step]
                        .toString())) &&
            type != LudoPlayerType.red) {
          if (player(LudoPlayerType.red).path[redElement.step].toString() ==
              path[step - 1].toString()) {
            killSomeone = true;
            player(LudoPlayerType.red).movePawn(i, -1);
            notifyListeners();
          }
        }
      }
    }
    return killSomeone;
  }

  void throwDice() async {
    if (_gameState != LudoGameState.throwDice) return;
    if (isOnlineGame && !isMyTurn) return;
    _diceStarted = true;
    notifyListeners();
    if (isOnlineGame) _broadcastState(); // sync dice rolling start to remotes
    Audio.rollDice();

    if (winners.contains(currentPlayer.type)) {
      nextTurnForMode();
      return;
    }

    currentPlayer.highlightAllPawns(false);

    Future.delayed(const Duration(seconds: 1)).then((value) async {
      _diceStarted = false;
      var random = Random();
      _diceResult = random.nextBool() ? 6 : random.nextInt(6) + 1;

      // Update consecutive six count
      if (diceResult == 6) {
        _consecutiveSixCount++;
      } else {
        _consecutiveSixCount = 0;
      }

      // If player rolls six 3rd time in a row: no move, turn changes
      if (_consecutiveSixCount >= 3) {
        _consecutiveSixCount = 0;
        notifyListeners();
        if (isOnlineGame) _broadcastState();
        // Skip this move completely and pass turn
        nextTurnForMode();
        return;
      }

      // Decide which pawns can actually move – only those will blink (highlight)
      currentPlayer.highlightAllPawns(false);
      bool anyMovable = false;
      for (var i = 0; i < currentPlayer.pawns.length; i++) {
        var pawn = currentPlayer.pawns[i];
        int step = pawn.step;
        bool canMove = false;

        if (diceResult == 6) {
          // From home: only with 6
          if (step == -1) {
            canMove = true;
          } else if (step >= 0 &&
              (step + diceResult) <= currentPlayer.path.length - 1) {
            canMove = true;
          }
        } else {
          // Normal move: pawn must be outside and not overshoot goal
          if (step >= 0 &&
              (step + diceResult) <= currentPlayer.path.length - 1) {
            canMove = true;
          }
        }

        currentPlayer.highlightPawn(i, canMove);
        if (canMove) anyMovable = true;
      }

      debugPrint(
          'After highlighting - Current player: ${currentPlayer.type}, Any movable: $anyMovable, Dice: $diceResult');
      debugPrint(
          'Highlighted pawns: ${currentPlayer.pawns.where((p) => p.highlight).length}');

      // Force UI update after highlighting
      notifyListeners();

      if (!anyMovable) {
        // No legal moves
        if (diceResult == 6) {
          _gameState = LudoGameState.throwDice;
          notifyListeners();
          if (isOnlineGame) _broadcastState();
        } else {
          nextTurnForMode();
          if (isOnlineGame) _broadcastState();
          return;
        }
      } else {
        // At least one pawn can move – let user pick / auto logic run
        _gameState = LudoGameState.pickPawn;
        notifyListeners();
        if (isOnlineGame) _broadcastState();
      }

      var moveablePawn = currentPlayer.pawns.where((e) => e.highlight).toList();

      debugPrint(
          'Dice result: $diceResult, Movable pawns: ${moveablePawn.length}, Inside count: ${currentPlayer.pawnInsideCount}');
      debugPrint(
          'Current player: ${currentPlayer.type}, Game state: $_gameState, isMyTurn: $isMyTurn');
      debugPrint(
          'Pawn steps: ${currentPlayer.pawns.map((p) => p.step).toList()}');
      debugPrint(
          'Pawn highlights: ${currentPlayer.pawns.map((p) => p.highlight).toList()}');

      // If all pawns are inside and 6 is rolled, automatically move one out
      if (diceResult == 6 &&
          currentPlayer.pawnInsideCount == 4 &&
          moveablePawn.length == 4) {
        debugPrint(
            'Auto-moving pawn out (all inside, 6 rolled) for ${currentPlayer.type}');
        var randomIndex = Random().nextInt(moveablePawn.length);
        var thePawn = moveablePawn[randomIndex];
        // Small delay to ensure UI is updated
        await Future.delayed(const Duration(milliseconds: 100));
        move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
        return;
      }

      // If only one pawn can move, automatically move it
      if (moveablePawn.length == 1) {
        debugPrint('Auto-moving single movable pawn for ${currentPlayer.type}');
        var thePawn = moveablePawn.first;
        // Small delay to ensure UI is updated
        await Future.delayed(const Duration(milliseconds: 100));
        if (thePawn.step == -1) {
          move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
        } else {
          move(thePawn.type, thePawn.index, (thePawn.step + 1) + diceResult);
        }
        return;
      }

      if (moveablePawn.length > 1) {
        var biggestStep = moveablePawn.map((e) => e.step).reduce(max);
        if (moveablePawn.every((element) => element.step == biggestStep)) {
          debugPrint('Auto-moving pawn (all at same step)');
          var random = Random().nextInt(moveablePawn.length);
          if (moveablePawn[random].step == -1) {
            var thePawn = moveablePawn[random];
            move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
            return;
          } else {
            var thePawn = moveablePawn[random];
            move(thePawn.type, thePawn.index, (thePawn.step + 1) + diceResult);
            return;
          }
        }
      }

      if (currentPlayer.pawns.every((element) => !element.highlight)) {
        debugPrint('No pawns highlighted, checking next action');
        if (diceResult == 6) {
          _gameState = LudoGameState.throwDice;
          notifyListeners();
          if (isOnlineGame) _broadcastState();
        } else {
          nextTurnForMode();
          if (isOnlineGame) _broadcastState();
          return;
        }
      }
    });
  }

  void move(LudoPlayerType type, int index, int step) async {
    // _isMoving normally blocks parallel animations, but sometimes it can stay
    // true on the local device after a remote animation. In that case we still
    // want to allow the **current** player to move while in pickPawn state.
    if (_isMoving) {
      final isCurrentTurn = type == _currentTurn;
      final isPickingPawn = _gameState == LudoGameState.pickPawn;
      if (!(isCurrentTurn && isPickingPawn)) {
        debugPrint('Move blocked: _isMoving is true');
        return;
      } else {
        debugPrint(
            'Overriding _isMoving=true for current player during pickPawn');
      }
    }
    if (isOnlineGame && !isMyTurn) {
      debugPrint(
          'Move blocked: Not my turn. Current turn: $_currentTurn, My color: $_myColor');
      return;
    }

    var selectedPlayer = player(type);
    if (index >= selectedPlayer.pawns.length) {
      debugPrint('Move blocked: Invalid pawn index $index');
      return;
    }

    // Check if the pawn is highlighted (can be moved) - but allow if it's the current player's turn
    // This allows auto-move to work even if highlighting check fails
    if (!selectedPlayer.pawns[index].highlight && type != _currentTurn) {
      debugPrint(
          'Move blocked: Pawn at index $index is not highlighted and not current player');
      return;
    }

    // If it's current player's turn but pawn not highlighted, re-check if it can move
    if (type == _currentTurn && !selectedPlayer.pawns[index].highlight) {
      int currentStep = selectedPlayer.pawns[index].step;
      bool canMove = false;

      if (_diceResult == 6) {
        if (currentStep == -1) {
          canMove = true;
        } else if (currentStep >= 0 &&
            (currentStep + _diceResult) <= selectedPlayer.path.length - 1) {
          canMove = true;
        }
      } else {
        if (currentStep >= 0 &&
            (currentStep + _diceResult) <= selectedPlayer.path.length - 1) {
          canMove = true;
        }
      }

      if (!canMove) {
        debugPrint(
            'Move blocked: Pawn at index $index cannot move (step: $currentStep, dice: $_diceResult)');
        return;
      }

      // Re-highlight the pawn if it can move
      selectedPlayer.highlightPawn(index, true);
      debugPrint('Re-highlighted pawn at index $index for current player');
    }

    _isMoving = true;
    _gameState = LudoGameState.moving;

    currentPlayer.highlightAllPawns(false);

    int currentStep = selectedPlayer.pawns[index].step;
    int startStep = currentStep == -1 ? 0 : currentStep;

    for (int i = startStep; i < step; i++) {
      if (_stopMoving) break;
      if (i == currentStep) continue;
      selectedPlayer.movePawn(index, i);
      // Update previous step tracking for local moves
      final pawnKey = '${type.name}_$index';
      _previousPawnSteps[pawnKey] = i;
      await Audio.playMove();
      notifyListeners();
      if (_stopMoving) break;
    }
    // Update final step
    final pawnKey = '${type.name}_$index';
    _previousPawnSteps[pawnKey] = step;

    if (checkToKill(type, index, step, selectedPlayer.path)) {
      _gameState = LudoGameState.throwDice;
      _isMoving = false;
      Audio.playKill();
      notifyListeners();
      if (isOnlineGame) _broadcastState();
      return;
    }

    validateWin(type);

    // If game finished after this move, stop here
    if (_gameState == LudoGameState.finish) {
      _isMoving = false;
      if (isOnlineGame) _broadcastState();
      return;
    }

    // Check if pawn reached goal (final position)
    bool reachedGoal = step >= selectedPlayer.path.length - 1;

    // If dice is 6 OR pawn reached goal, player gets another turn
    if (diceResult == 6 || reachedGoal) {
      _gameState = LudoGameState.throwDice;
      notifyListeners();
    } else {
      nextTurnForMode();
    }
    _isMoving = false;
    if (isOnlineGame) _broadcastState();
  }

  void nextTurn() {
    // Clear highlights for all players when turn changes
    for (var player in players) {
      player.highlightAllPawns(false);
    }

    int attempts = 0;
    do {
      switch (_currentTurn) {
        case LudoPlayerType.green:
          _currentTurn = LudoPlayerType.yellow;
          break;
        case LudoPlayerType.yellow:
          _currentTurn = LudoPlayerType.blue;
          break;
        case LudoPlayerType.blue:
          _currentTurn = LudoPlayerType.red;
          break;
        case LudoPlayerType.red:
          _currentTurn = LudoPlayerType.green;
          break;
      }
      attempts++;
      // Prevent infinite loop
      if (attempts > 4) break;
    } while (winners.contains(_currentTurn) ||
        offlinePlayers.contains(_currentTurn));

    // New turn: reset consecutive six counter
    _consecutiveSixCount = 0;

    // Play sound only when turn changes TO local user (not when turn goes away from local user)
    if (!isOnlineGame || _currentTurn == _myColor) {
      Audio.playTurnChange();
    }

    _gameState = LudoGameState.throwDice;
    notifyListeners();
    if (isOnlineGame) _broadcastState();
  }

  void validateWin(LudoPlayerType color) {
    if (winners.map((e) => e.name).contains(color.name)) return;
    if (player(color)
        .pawns
        .map((e) => e.step)
        .every((element) => element == player(color).path.length - 1)) {
      winners.add(color);
      _gameState = LudoGameState.finish;
      if (isOnlineGame) _broadcastState();
    }
  }

  /// [playerCount] 2 = 2v2 (Green vs Red), 4 = 4v4 (all players)
  /// [matchId] [userId] [playerList] for online real-time sync
  void startGame({
    int playerCount = 4,
    String? matchId,
    String? userId,
    List<Map<String, dynamic>>? playerList,
  }) {
    _matchId = matchId;
    _userId = userId;
    _gameSubscription?.cancel();
    _matchRef = null;
    _myColor = null;

    winners.clear();
    players.clear();
    _previousPawnSteps.clear(); // Reset previous steps tracking
    offlinePlayers.clear(); // Reset offline players
    players.addAll([
      LudoPlayer2v2(LudoPlayerType.green),
      LudoPlayer2v2(LudoPlayerType.yellow),
      LudoPlayer2v2(LudoPlayerType.blue),
      LudoPlayer2v2(LudoPlayerType.red),
    ]);

    // Note: for 2-player mode we use Green vs Blue logically.
    // Red & Yellow players stay idle and are ignored by board/filter logic.
    // Initialize previous steps for all pawns
    for (var player in players) {
      for (int i = 0; i < player.pawns.length; i++) {
        _previousPawnSteps['${player.type.name}_$i'] = player.pawns[i].step;
      }
    }
    _playerCount = playerCount;
    _consecutiveSixCount = 0;
    _currentTurn = LudoPlayerType.green;
    _gameState = LudoGameState.throwDice;
    _diceResult = 1;

    if (matchId != null &&
        userId != null &&
        playerList != null &&
        playerList.isNotEmpty) {
      _initOnlineGame(playerList);
    }

    // startGame() is called from GameScreen2v2.initState; defer notifyListeners
    // to next frame to avoid "setState() called during build" assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  static const List<LudoPlayerType> _colorOrder = [
    LudoPlayerType.green,
    LudoPlayerType.yellow,
    LudoPlayerType.blue,
    LudoPlayerType.red,
  ];

  void _initOnlineGame(List<Map<String, dynamic>> playerList) {
    // Remove duplicates and sort by id to ensure consistent color assignment across all devices
    final uniquePlayers = <String, Map<String, dynamic>>{};
    for (var player in playerList) {
      final playerId = player['id']?.toString() ?? '';
      if (playerId.isNotEmpty && !uniquePlayers.containsKey(playerId)) {
        uniquePlayers[playerId] = player;
      }
    }

    // Sort players by id to ensure consistent order across all devices
    final sortedPlayerIds = uniquePlayers.keys.toList()..sort();
    final sortedPlayerList =
        sortedPlayerIds.map((id) => uniquePlayers[id]!).toList();

    // Find current user's index in sorted list
    int myIndex = -1;
    for (int i = 0; i < sortedPlayerList.length; i++) {
      if (sortedPlayerList[i]['id']?.toString() == _userId) {
        myIndex = i;
        break;
      }
    }
    if (myIndex < 0) myIndex = 0;

    // Assign color based on sorted position
    // 2-player: Green (P1) vs Blue (P2)
    _myColor = _playerCount == 2
        ? (myIndex == 0 ? LudoPlayerType.green : LudoPlayerType.blue)
        : _colorOrder[myIndex.clamp(0, 3)];

    _matchRef = FirebaseDatabase.instance.ref('games/$_matchId');
    _gameSubscription = _matchRef!.onValue.listen((event) {
      final snap = event.snapshot.value;
      if (snap == null) return;
      final data = Map<dynamic, dynamic>.from(snap as Map);
      if (data['lastUpdatedBy']?.toString() == _userId) return;
      _applyRemoteState(data);
    });

    _matchRef!.once().then((snapshot) {
      final snap = snapshot.snapshot.value;
      if (snap != null) {
        _applyRemoteState(Map<dynamic, dynamic>.from(snap as Map));
      } else {
        _broadcastState();
      }
    });
  }

  void _applyRemoteState(Map<dynamic, dynamic> data) async {
    try {
      // Store previous turn to detect if turn changed TO local user
      final previousTurn = _currentTurn;

      _currentTurn = LudoPlayerType.values.firstWhere(
        (e) => e.toString() == data['currentTurn'],
        orElse: () => LudoPlayerType.green,
      );

      // Play sound only when turn changes TO local user (not when turn goes away from local user)
      if (isOnlineGame &&
          _myColor != null &&
          previousTurn != _currentTurn &&
          _currentTurn == _myColor) {
        Audio.playTurnChange();
      }

      // If turn changed to a different player, reset pawn highlights for the new player
      if (previousTurn != _currentTurn) {
        // Clear highlights for all players when turn changes
        for (var player in players) {
          player.highlightAllPawns(false);
        }
      }

      _diceResult = (data['diceResult'] ?? 1) is int
          ? data['diceResult'] as int
          : int.tryParse(data['diceResult'].toString()) ?? 1;
      _diceStarted = data['diceStarted'] == true ||
          data['diceStarted']?.toString() == 'true';
      _consecutiveSixCount = (data['consecutiveSixCount'] ?? 0) is int
          ? data['consecutiveSixCount'] as int
          : int.tryParse(data['consecutiveSixCount']?.toString() ?? '0') ?? 0;
      _gameState = LudoGameState.values.firstWhere(
        (e) => e.toString() == data['gameState'],
        orElse: () => LudoGameState.throwDice,
      );

      // If it's local user's turn and game state is throwDice, ensure pawns are not highlighted
      if (isOnlineGame &&
          _myColor != null &&
          _currentTurn == _myColor &&
          _gameState == LudoGameState.throwDice) {
        currentPlayer.highlightAllPawns(false);
      }

      // If it's local user's turn and game state is pickPawn, re-apply highlighting based on dice result
      if (isOnlineGame &&
          _myColor != null &&
          _currentTurn == _myColor &&
          _gameState == LudoGameState.pickPawn) {
        currentPlayer.highlightAllPawns(false);
        bool anyMovable = false;
        for (var i = 0; i < currentPlayer.pawns.length; i++) {
          var pawn = currentPlayer.pawns[i];
          int step = pawn.step;
          bool canMove = false;

          if (_diceResult == 6) {
            // From home: only with 6
            if (step == -1) {
              canMove = true;
            } else if (step >= 0 &&
                (step + _diceResult) <= currentPlayer.path.length - 1) {
              canMove = true;
            }
          } else {
            // Normal move: pawn must be outside and not overshoot goal
            if (step >= 0 &&
                (step + _diceResult) <= currentPlayer.path.length - 1) {
              canMove = true;
            }
          }

          currentPlayer.highlightPawn(i, canMove);
          if (canMove) anyMovable = true;
        }

        // Force UI update after highlighting
        notifyListeners();

        // If pawns are highlighted, trigger auto-move logic if applicable
        if (anyMovable) {
          var moveablePawn =
              currentPlayer.pawns.where((e) => e.highlight).toList();

          debugPrint(
              'Remote state - Dice: $_diceResult, Movable: ${moveablePawn.length}, Inside: ${currentPlayer.pawnInsideCount}');

          // If all pawns are inside and 6 is rolled, automatically move one out
          if (_diceResult == 6 &&
              currentPlayer.pawnInsideCount == 4 &&
              moveablePawn.length == 4) {
            debugPrint(
                'Remote state - Auto-moving pawn out (all inside, 6 rolled)');
            var randomIndex = Random().nextInt(moveablePawn.length);
            var thePawn = moveablePawn[randomIndex];
            move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
            return;
          }

          // If only one pawn can move, auto-move it
          if (moveablePawn.length == 1) {
            debugPrint('Remote state - Auto-moving single movable pawn');
            var thePawn = moveablePawn.first;
            if (thePawn.step == -1) {
              move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
            } else {
              move(thePawn.type, thePawn.index,
                  (thePawn.step + 1) + _diceResult);
            }
            return;
          }
        }
      }

      // Update offline players from remote state
      if (data['offlinePlayers'] != null) {
        final offlineList = data['offlinePlayers'] is List
            ? data['offlinePlayers'] as List
            : [];
        _offlinePlayers = Set<LudoPlayerType>.from(
            offlineList.map((e) => LudoPlayerType.values.firstWhere(
                  (p) => p.toString() == e.toString(),
                  orElse: () => LudoPlayerType.green,
                )));
      }
      final playersData = data['players'];
      if (playersData is List && players.length == playersData.length) {
        // First, detect movements before updating
        List<Map<String, dynamic>> movementsToAnimate = [];
        for (int i = 0; i < players.length && i < playersData.length; i++) {
          try {
            final player = players[i];
            if (player.pawns.isEmpty) continue;

            final m = playersData[i] is Map
                ? Map<dynamic, dynamic>.from(playersData[i] as Map)
                : <dynamic, dynamic>{};
            final pawnsData = m['pawns'];
            if (pawnsData != null) {
              final list =
                  pawnsData is List ? pawnsData : pawnsData.values.toList();
              for (int j = 0; j < player.pawns.length && j < list.length; j++) {
                try {
                  final pawnMap = list[j] is Map
                      ? Map<dynamic, dynamic>.from(list[j] as Map)
                      : <dynamic, dynamic>{};
                  final stepValue = pawnMap['step'];
                  final newStep = stepValue is int
                      ? stepValue
                      : (stepValue != null
                              ? int.tryParse(stepValue.toString())
                              : null) ??
                          player.pawns[j].step;
                  final pawnKey = '${player.type.name}_$j';
                  final previousStep =
                      _previousPawnSteps[pawnKey] ?? player.pawns[j].step;

                  // Detect movement for remote players only (in online mode)
                  // Only animate if it's not my color (remote player's move)
                  bool isRemotePlayer = isOnlineGame &&
                      _myColor != null &&
                      player.type != _myColor;

                  if (newStep != previousStep && isRemotePlayer) {
                    // Only animate forward movement or coming out
                    if ((previousStep == -1 && newStep >= 0) ||
                        (previousStep >= 0 && newStep > previousStep)) {
                      debugPrint(
                          'Detected movement: ${player.type.name} pawn $j from $previousStep to $newStep');
                      movementsToAnimate.add({
                        'type': player.type,
                        'index': j,
                        'fromStep': previousStep,
                        'toStep': newStep,
                      });
                    }
                  }
                } catch (e) {
                  debugPrint(
                      'Error processing pawn $j for player ${player.type}: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('Error processing player $i: $e');
          }
        }

        // Animate movements if any (BEFORE updating final state)
        // Use separate flag so local _isMoving (for this device's moves)
        // does NOT block remote opponent animations.
        if (movementsToAnimate.isNotEmpty && !_isRemoteAnimating) {
          debugPrint(
              'Animating ${movementsToAnimate.length} remote pawn movements (2v2)');
          _isRemoteAnimating = true;
          _gameState = LudoGameState.moving;
          notifyListeners();

          for (var movement in movementsToAnimate) {
            final playerType = movement['type'] as LudoPlayerType;
            final index = movement['index'] as int;
            final fromStep = movement['fromStep'] as int;
            final toStep = movement['toStep'] as int;
            final selectedPlayer = player(playerType);

            debugPrint(
                'Animating ${playerType.name} pawn $index from step $fromStep to $toStep (2v2)');

            // Start from previous step (reset to start position)
            selectedPlayer.movePawn(index, fromStep);
            notifyListeners();
            await Future.delayed(
                const Duration(milliseconds: 50)); // Reduced from 100ms

            // Animate step by step
            int startStep = fromStep == -1 ? 0 : fromStep + 1;
            for (int step = startStep; step <= toStep; step++) {
              if (_stopMoving) break;
              selectedPlayer.movePawn(index, step);
              notifyListeners();
              await Audio.playMove();
              await Future.delayed(const Duration(
                  milliseconds:
                      100)); // Reduced from 250ms to match local speed
              if (_stopMoving) break;
            }

            // Check for kills
            if (toStep > fromStep && toStep > 0) {
              checkToKill(playerType, index, toStep, selectedPlayer.path);
            }
          }

          _isRemoteAnimating = false;
          _gameState = LudoGameState.throwDice;
          notifyListeners();
          debugPrint('Animation completed (2v2)');
        } else if (movementsToAnimate.isNotEmpty) {
          debugPrint(
              'Skipping remote animation (2v2): _isRemoteAnimating = $_isRemoteAnimating');
        }

        // Update all players' pawns to final state (after animation or if no animation needed)
        // Skip updating pawns that were just animated (they're already at final position)
        Set<String> animatedPawns = {};
        if (movementsToAnimate.isNotEmpty) {
          for (var movement in movementsToAnimate) {
            final playerType = movement['type'] as LudoPlayerType;
            final index = movement['index'] as int;
            animatedPawns.add('${playerType.name}_$index');
          }
        }

        for (int i = 0; i < players.length && i < playersData.length; i++) {
          try {
            final m = playersData[i] is Map
                ? Map<dynamic, dynamic>.from(playersData[i] as Map)
                : <dynamic, dynamic>{};

            // If pawns were animated, they're already at final position, so update other data only
            if (animatedPawns.isNotEmpty) {
              // Update only non-animated pawns or update all if no animation happened
              players[i].updateFromMap(m);
            } else {
              // No animation, update normally
              players[i].updateFromMap(m);
            }

            // Update previous steps tracking
            final player = players[i];
            if (player.pawns.isEmpty) continue;

            final pawnsData = m['pawns'];
            if (pawnsData != null) {
              final list =
                  pawnsData is List ? pawnsData : pawnsData.values.toList();
              for (int j = 0; j < player.pawns.length && j < list.length; j++) {
                try {
                  final pawnMap = list[j] is Map
                      ? Map<dynamic, dynamic>.from(list[j] as Map)
                      : <dynamic, dynamic>{};
                  final stepValue = pawnMap['step'];
                  final newStep = stepValue is int
                      ? stepValue
                      : (stepValue != null
                              ? int.tryParse(stepValue.toString())
                              : null) ??
                          player.pawns[j].step;
                  final pawnKey = '${player.type.name}_$j';
                  _previousPawnSteps[pawnKey] = newStep;
                } catch (e) {
                  debugPrint('Error updating step for pawn $j: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('Error updating player $i: $e');
          }
        }
      }
      winners.clear();
      final w = data['winners'];
      if (w is List) {
        for (var item in w) {
          final s = item.toString();
          try {
            winners.add(
                LudoPlayerType.values.firstWhere((e) => e.toString() == s));
          } catch (_) {}
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Ludo _applyRemoteState error: $e');
    }
  }

  void _broadcastState() {
    if (_matchRef == null || _userId == null) {
      debugPrint(
          'Ludo _broadcastState: _matchRef or _userId is null. matchRef: $_matchRef, userId: $_userId');
      return;
    }
    try {
      final stateData = {
        'currentTurn': _currentTurn.toString(),
        'diceResult': _diceResult,
        'gameState': _gameState.toString(),
        'diceStarted': _diceStarted,
        'players': players.map((p) => p.toMap()).toList(),
        'winners': winners.map((w) => w.toString()).toList(),
        'playerCount': _playerCount,
        'consecutiveSixCount': _consecutiveSixCount,
        'offlinePlayers': offlinePlayers.map((p) => p.toString()).toList(),
        'lastUpdated': ServerValue.timestamp,
        'lastUpdatedBy': _userId,
      };
      debugPrint(
          'Ludo _broadcastState: Broadcasting state - turn: ${_currentTurn}, dice: $_diceResult, state: $_gameState');
      _matchRef!.update(stateData).then((_) {
        debugPrint('Ludo _broadcastState: Successfully broadcasted state');
      }).catchError((error) {
        debugPrint('Ludo _broadcastState error: $error');
      });
    } catch (e) {
      debugPrint('Ludo _broadcastState error: $e');
    }
  }

  // Mark player as offline
  void markPlayerOffline(LudoPlayerType playerType) {
    if (!offlinePlayers.contains(playerType)) {
      offlinePlayers.add(playerType);
      notifyListeners();
      if (isOnlineGame) _broadcastState();
    }
  }

  // Mark player as online
  void markPlayerOnline(LudoPlayerType playerType) {
    if (offlinePlayers.contains(playerType)) {
      offlinePlayers.remove(playerType);
      notifyListeners();
      if (isOnlineGame) _broadcastState();
    }
  }

  // Handle user leaving the game
  void handleUserLeave() {
    if (isOnlineGame && _myColor != null) {
      markPlayerOffline(_myColor!);
      // Update Firebase to mark this player as offline
      if (_matchRef != null) {
        _matchRef!
            .child('offlinePlayers')
            .set(offlinePlayers.map((p) => p.toString()).toList());
      }
    }
  }

  int _playerCount = 4;
  int get playerCount => _playerCount;

  /// Next turn - for 2v2 only Green<->Blue, for 4v4 cycles all
  void nextTurnForMode() {
    // Clear highlights for all players when turn changes
    for (var player in players) {
      player.highlightAllPawns(false);
    }

    if (_playerCount == 2) {
      // For 2v2, skip offline players (Green <-> Blue)
      int attempts = 0;
      do {
        _currentTurn = _currentTurn == LudoPlayerType.green
            ? LudoPlayerType.blue
            : LudoPlayerType.green;
        attempts++;
        if (attempts > 2) break; // Prevent infinite loop
      } while (winners.contains(_currentTurn) ||
          offlinePlayers.contains(_currentTurn));
    } else {
      nextTurn();
      // nextTurn() already calls _broadcastState() and plays sound, so return here
      return;
    }
    // New turn: reset consecutive six counter
    _consecutiveSixCount = 0;

    // Play sound only when turn changes TO local user (not when turn goes away from local user)
    if (!isOnlineGame || _currentTurn == _myColor) {
      Audio.playTurnChange();
    }

    _gameState = LudoGameState.throwDice;
    notifyListeners();
    if (isOnlineGame) _broadcastState();
  }

  @override
  void dispose() {
    handleUserLeave();
    _stopMoving = true;
    _gameSubscription?.cancel();
    super.dispose();
  }

  static Ludo2v2 read(BuildContext context) => context.read();
}
