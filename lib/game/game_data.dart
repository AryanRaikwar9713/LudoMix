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
                color: color,
                minRadius: 20,
                repeat: true,
                ripplesCount: 3,
                child: const SizedBox.shrink()),
          Consumer<Ludo>(
            builder: (context, provider, child) => GestureDetector(
              onTap: () {
                if (step == -1) {
                  provider.move(type, index, (step + 1) + 1);
                } else {
                  provider.move(type, index, (step + 1) + provider.diceResult);
                }
                context.read<Ludo>().move(type, index, step);
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
      final m = list[i] is Map ? Map<dynamic, dynamic>.from(list[i] as Map) : <dynamic, dynamic>{};
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
      notifyListeners();
      if (isOnlineGame) _broadcastState();

      if (diceResult == 6) {
        currentPlayer.highlightAllPawns();
        _gameState = LudoGameState.pickPawn;
        notifyListeners();
        if (isOnlineGame) _broadcastState();
      } else {
        if (currentPlayer.pawnInsideCount == 4) {
          nextTurnForMode();
          if (isOnlineGame) _broadcastState();
          return;
        } else {
          currentPlayer.highlightOutside();
          _gameState = LudoGameState.pickPawn;
          notifyListeners();
          if (isOnlineGame) _broadcastState();
        }
      }

      for (var i = 0; i < currentPlayer.pawns.length; i++) {
        var pawn = currentPlayer.pawns[i];
        if ((pawn.step + diceResult) > currentPlayer.path.length - 1) {
          currentPlayer.highlightPawn(i, false);
        }
      }

      var moveablePawn = currentPlayer.pawns.where((e) => e.highlight).toList();
      if (moveablePawn.length > 1) {
        var biggestStep = moveablePawn.map((e) => e.step).reduce(max);
        if (moveablePawn.every((element) => element.step == biggestStep)) {
          var random = 1 + Random().nextInt(moveablePawn.length - 1);
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
    for (int i = selectedPlayer.pawns[index].step; i < step; i++) {
      if (_stopMoving) break;
      if (selectedPlayer.pawns[index].step == i) continue;
      selectedPlayer.movePawn(index, i);
      await Audio.playMove();
      notifyListeners();
      if (_stopMoving) break;
    }
    if (checkToKill(type, index, step, selectedPlayer.path)) {
      _gameState = LudoGameState.throwDice;
      _isMoving = false;
      Audio.playKill();
      notifyListeners();
      if (isOnlineGame) _broadcastState();
      return;
    }

    validateWin(type);

    if (diceResult == 6) {
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

    if (winners.contains(_currentTurn)) return nextTurn();
    _gameState = LudoGameState.throwDice;
    notifyListeners();
  }

  void validateWin(LudoPlayerType color) {
    if (winners.map((e) => e.name).contains(color.name)) return;
    if (player(color)
        .pawns
        .map((e) => e.step)
        .every((element) => element == player(color).path.length - 1)) {
      winners.add(color);
      notifyListeners();
    }

    // 2v2: 1 winner = game over. 4v4: 3 winners (4th loses) = game over
    if ((_playerCount == 2 && winners.length == 1) || winners.length == 3) {
      _gameState = LudoGameState.finish;
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
    players.addAll([
      LudoPlayer(LudoPlayerType.green),
      LudoPlayer(LudoPlayerType.yellow),
      LudoPlayer(LudoPlayerType.blue),
      LudoPlayer(LudoPlayerType.red),
    ]);
    _playerCount = playerCount;
    _currentTurn = LudoPlayerType.green;
    _gameState = LudoGameState.throwDice;
    _diceResult = 1;

    if (matchId != null && userId != null && playerList != null && playerList.isNotEmpty) {
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
    int myIndex = -1;
    for (int i = 0; i < playerList.length; i++) {
      if (playerList[i]['id']?.toString() == _userId) {
        myIndex = i;
        break;
      }
    }
    if (myIndex < 0) myIndex = 0;
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

  void _applyRemoteState(Map<dynamic, dynamic> data) {
    try {
      _currentTurn = LudoPlayerType.values.firstWhere(
        (e) => e.toString() == data['currentTurn'],
        orElse: () => LudoPlayerType.green,
      );
      _diceResult = (data['diceResult'] ?? 1) is int
          ? data['diceResult'] as int
          : int.tryParse(data['diceResult'].toString()) ?? 1;
      _gameState = LudoGameState.values.firstWhere(
        (e) => e.toString() == data['gameState'],
        orElse: () => LudoGameState.throwDice,
      );
      final playersData = data['players'];
      if (playersData is List && players.length == playersData.length) {
        for (int i = 0; i < players.length && i < playersData.length; i++) {
          final m = playersData[i] is Map
              ? Map<dynamic, dynamic>.from(playersData[i] as Map)
              : <dynamic, dynamic>{};
          players[i].updateFromMap(m);
        }
      }
      winners.clear();
      final w = data['winners'];
      if (w is List) {
        for (var item in w) {
          final s = item.toString();
          try {
            winners.add(LudoPlayerType.values.firstWhere((e) => e.toString() == s));
          } catch (_) {}
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Ludo _applyRemoteState error: $e');
    }
  }

  void _broadcastState() {
    if (_matchRef == null || _userId == null) return;
    try {
      _matchRef!.update({
        'currentTurn': _currentTurn.toString(),
        'diceResult': _diceResult,
        'gameState': _gameState.toString(),
        'players': players.map((p) => p.toMap()).toList(),
        'winners': winners.map((w) => w.toString()).toList(),
        'playerCount': _playerCount,
        'lastUpdated': ServerValue.timestamp,
        'lastUpdatedBy': _userId,
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
    }
    if (winners.contains(_currentTurn)) return nextTurnForMode();
    _gameState = LudoGameState.throwDice;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopMoving = true;
    _gameSubscription?.cancel();
    super.dispose();
  }

  static Ludo read(BuildContext context) => context.read();
}
