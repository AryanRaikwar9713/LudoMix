import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:provider/provider.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';
import 'dart:async';
import 'dart:math';

class Audio {
  static AudioPlayer audioPlayer = AudioPlayer();

  static Future<void> playMove() async {
    var duration = await audioPlayer.setAsset('assets/sounds/move.wav');
    audioPlayer.play();
    return Future.delayed(duration ?? Duration.zero);
  }

  static Future<void> playKill() async {
    var duration = await audioPlayer.setAsset('assets/sounds/laugh.mp3');
    audioPlayer.play();
    return Future.delayed(duration ?? Duration.zero);
  }

  static Future<void> rollDice() async {
    var duration =
        await audioPlayer.setAsset('assets/sounds/roll_the_dice.mp3');
    audioPlayer.play();
    return Future.delayed(duration ?? Duration.zero);
  }
}

class PawnWidget extends StatelessWidget {
  final int index;
  final LudoPlayerType type;
  final int step;
  final bool highlight;

  const PawnWidget(this.index, this.type,
      {super.key, this.highlight = false, this.step = -1});

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'type': type.toString(),
      'step': step,
      'highlight': highlight,
    };
  }

  PawnWidget updateFromMap(Map<dynamic, dynamic> data) {
    return PawnWidget(
      data['index'] ?? index,
      LudoPlayerType.values.firstWhere((e) => e.toString() == data['type']),
      step: data['step'] ?? step,
      highlight: data['highlight'] ?? highlight,
    );
  }

  @override
  Widget build(BuildContext context) {
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
        color = LudoColor.red;
        break;
    }
    return IgnorePointer(
      ignoring: !highlight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (highlight)
            RippleAnimation(
                color: color.withOpacity(0.7),
                minRadius: 12, // smaller ripple
                repeat: true,
                ripplesCount: 2,
                child: const SizedBox.shrink()),
          Consumer<Ludo>(
            builder: (context, provider, child) => GestureDetector(
              onTap: () {
                if (step == -1) {
                  provider.move(type, index, (step + 1) + 1);
                } else {
                  provider.move(type, index, (step + 1) + provider.diceResult);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2)),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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

class LudoPlayer {
  final LudoPlayerType type;
  late List<List<double>> path;
  late List<List<double>> homePath;
  final List<PawnWidget> pawns = [];
  late Color color;

  LudoPlayer(this.type) {
    for (int i = 0; i < 4; i++) {
      pawns.add(PawnWidget(i, type));
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
    pawns[index] = PawnWidget(index, type, step: step, highlight: false);
  }

  void highlightPawn(int index, [bool highlight = true]) {
    var pawn = pawns[index];
    pawns.removeAt(index);
    pawns.insert(index,
        PawnWidget(index, pawn.type, highlight: highlight, step: pawn.step));
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

class Ludo extends ChangeNotifier {
  bool _isMoving = false;
  bool _stopMoving = false;
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
  LudoPlayer get currentPlayer =>
      players.firstWhere((element) => element.type == _currentTurn);
  final List<LudoPlayer> players = [];
  final List<LudoPlayerType> winners = [];

  LudoPlayer player(LudoPlayerType type) =>
      players.firstWhere((element) => element.type == type);

  bool checkToKill(
      LudoPlayerType type, int index, int step, List<List<double>> path) {
    bool killSomeone = false;
    for (int i = 0; i < 4; i++) {
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
        if (player(LudoPlayerType.yellow).path[yellowElement.step].toString() ==
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

    Future.delayed(const Duration(seconds: 1)).then((value) {
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

      // If all pawns are inside and 6 is rolled, automatically move one out
      if (diceResult == 6 &&
          currentPlayer.pawnInsideCount == 4 &&
          moveablePawn.length == 4) {
        var randomIndex = Random().nextInt(moveablePawn.length);
        var thePawn = moveablePawn[randomIndex];
        move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
        return;
      }

      if (moveablePawn.length > 1) {
        var biggestStep = moveablePawn.map((e) => e.step).reduce(max);
        if (moveablePawn.every((element) => element.step == biggestStep)) {
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

      if (currentPlayer.pawns.where((element) => element.highlight).length ==
          1) {
        var index =
            currentPlayer.pawns.indexWhere((element) => element.highlight);
        move(currentPlayer.type, index,
            (currentPlayer.pawns[index].step + 1) + diceResult);
      }
    });
  }

  void move(LudoPlayerType type, int index, int step) async {
    if (_isMoving) return;
    if (isOnlineGame && !isMyTurn) return;
    _isMoving = true;
    _gameState = LudoGameState.moving;

    currentPlayer.highlightAllPawns(false);

    var selectedPlayer = player(type);
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

    // New turn: reset consecutive six counter
    _consecutiveSixCount = 0;

    if (winners.contains(_currentTurn)) return nextTurn();
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
    players.addAll([
      LudoPlayer(LudoPlayerType.green),
      LudoPlayer(LudoPlayerType.yellow),
      LudoPlayer(LudoPlayerType.blue),
      LudoPlayer(LudoPlayerType.red),
    ]);
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
    notifyListeners();
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
    _myColor = _playerCount == 2
        ? (myIndex == 0 ? LudoPlayerType.green : LudoPlayerType.red)
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
      _currentTurn = LudoPlayerType.values.firstWhere(
        (e) => e.toString() == data['currentTurn'],
        orElse: () => LudoPlayerType.green,
      );
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
        if (movementsToAnimate.isNotEmpty && !_isMoving) {
          debugPrint(
              'Animating ${movementsToAnimate.length} remote pawn movements');
          _isMoving = true;
          _gameState = LudoGameState.moving;
          notifyListeners();

          for (var movement in movementsToAnimate) {
            final playerType = movement['type'] as LudoPlayerType;
            final index = movement['index'] as int;
            final fromStep = movement['fromStep'] as int;
            final toStep = movement['toStep'] as int;
            final selectedPlayer = player(playerType);

            debugPrint(
                'Animating ${playerType.name} pawn $index from step $fromStep to $toStep');

            // Start from previous step (reset to start position)
            selectedPlayer.movePawn(index, fromStep);
            notifyListeners();
            await Future.delayed(const Duration(milliseconds: 100));

            // Animate step by step
            int startStep = fromStep == -1 ? 0 : fromStep + 1;
            for (int step = startStep; step <= toStep; step++) {
              if (_stopMoving) break;
              selectedPlayer.movePawn(index, step);
              notifyListeners();
              await Audio.playMove();
              await Future.delayed(const Duration(milliseconds: 250));
              if (_stopMoving) break;
            }

            // Check for kills
            if (toStep > fromStep && toStep > 0) {
              checkToKill(playerType, index, toStep, selectedPlayer.path);
            }
          }

          _isMoving = false;
          _gameState = LudoGameState.throwDice;
          notifyListeners();
          debugPrint('Animation completed');
        } else if (movementsToAnimate.isNotEmpty) {
          debugPrint('Skipping animation: _isMoving = $_isMoving');
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

  int _playerCount = 4;
  int get playerCount => _playerCount;

  /// Next turn - for 2v2 only Green<->Red, for 4v4 cycles all
  void nextTurnForMode() {
    if (_playerCount == 2) {
      _currentTurn = _currentTurn == LudoPlayerType.green
          ? LudoPlayerType.red
          : LudoPlayerType.green;
    } else {
      nextTurn();
      // nextTurn() already calls _broadcastState(), so return here
      return;
    }
    // New turn: reset consecutive six counter
    _consecutiveSixCount = 0;
    if (winners.contains(_currentTurn)) return nextTurnForMode();
    _gameState = LudoGameState.throwDice;
    notifyListeners();
    if (isOnlineGame) _broadcastState();
  }

  @override
  void dispose() {
    _stopMoving = true;
    _gameSubscription?.cancel();
    super.dispose();
  }

  static Ludo read(BuildContext context) => context.read();
}
