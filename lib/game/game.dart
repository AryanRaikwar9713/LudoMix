import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:ludo_flutter/utils/const_res.dart';
import 'package:provider/provider.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';
import 'game_data.dart'; // Import the first part (Assuming this is correct)

// Keep your existing DiceWidget class as is
class DiceWidget extends StatelessWidget {
  const DiceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<Ludo>(
      builder: (context, value, child) => RippleAnimation(
        // Glow sirf us user ko dikhni chahiye jiska turn hai (isMyTurn)
        // Dice animation (gif) sabko dikh sakta hai, par color ripple local hi rahega
        color: (value.diceStarted || value.gameState == LudoGameState.throwDice) &&
                value.isMyTurn
            ? value.currentPlayer.color
            : Colors.white.withOpacity(0),
        ripplesCount: 3,
        minRadius: 30,
        repeat: true,
        child: CupertinoButton(
          // Only current user can roll, but everyone sees the animation/result
          onPressed: (value.gameState == LudoGameState.throwDice && value.isMyTurn)
              ? value.throwDice
              : null,
          padding: const EdgeInsets.only(),
          child: value.diceStarted
              ? Image.asset(
                  "assets/images/dice/draw.gif",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text('Failed to load dice animation!');
                  },
                )
              : Image.asset(
                  "assets/images/dice/${value.diceResult}.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                        'Failed to load dice image: ${value.diceResult}.png');
                  },
                ),
        ),
      ),
    );
  }
}

// Keep your existing BoardWidget class as is
class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key});

  double ludoBoard(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 500) {
      return 500;
    } else {
      if (width < 300) {
        return 300;
      } else {
        return width - 20;
      }
    }
  }

  double boxStepSize(BuildContext context) {
    return ludoBoard(context) / 15;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(10),
          clipBehavior: Clip.antiAlias,
          width: ludoBoard(context),
          height: ludoBoard(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            image: const DecorationImage(
              image: AssetImage("assets/images/board.png"),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          child: Consumer<Ludo>(
            builder: (context, value, child) {
              List<LudoPlayer> players = List.from(value.players);
              Map<String, List<PawnWidget>> pawnsRaw = {};
              Map<String, List<String>> pawnsToPrint = {};
              List<Widget> playersPawn = [];

              players
                  .sort((a, b) => value.currentPlayer.type == a.type ? 1 : -1);

              for (int i = 0; i < players.length; i++) {
                var player = players[i];
                for (int j = 0; j < player.pawns.length; j++) {
                  var pawn = player.pawns[j];
                  if (pawn.step > -1) {
                    String step = player.path[pawn.step].toString();
                    if (pawnsRaw[step] == null) {
                      pawnsRaw[step] = [];
                      pawnsToPrint[step] = [];
                    }
                    pawnsRaw[step]!.add(pawn);
                    pawnsToPrint[step]!.add(player.type.toString());
                  } else {
                    if (pawnsRaw["home"] == null) {
                      pawnsRaw["home"] = [];
                      pawnsToPrint["home"] = [];
                    }
                    pawnsRaw["home"]!.add(pawn);
                    pawnsToPrint["home"]!.add(player.type.toString());
                  }
                }
              }

              for (String key in pawnsRaw.keys) {
                List<PawnWidget> pawnsValue = pawnsRaw[key]!;
                if (key == "home") {
                  playersPawn.addAll(
                    pawnsValue.map((e) {
                      var player = value.players
                          .firstWhere((element) => element.type == e.type);
                      return AnimatedPositioned(
                        key: ValueKey("${e.type.name}_${e.index}"),
                        left: LudoPath.stepBox(
                            ludoBoard(context), player.homePath[e.index][0]),
                        top: LudoPath.stepBox(
                            ludoBoard(context), player.homePath[e.index][1]),
                        width: boxStepSize(context),
                        height: boxStepSize(context),
                        duration: const Duration(milliseconds: 200),
                        child: e,
                      );
                    }),
                  );
                } else {
                  List<double> coordinates = key
                      .replaceAll("[", "")
                      .replaceAll("]", "")
                      .split(",")
                      .map((e) => double.parse(e.trim()))
                      .toList();
                  if (pawnsValue.length == 1) {
                    var e = pawnsValue.first;
                    playersPawn.add(AnimatedPositioned(
                      key: ValueKey("${e.type.name}_${e.index}"),
                      duration: const Duration(milliseconds: 200),
                      left:
                          LudoPath.stepBox(ludoBoard(context), coordinates[0]),
                      top: LudoPath.stepBox(ludoBoard(context), coordinates[1]),
                      width: boxStepSize(context),
                      height: boxStepSize(context),
                      child: pawnsValue.first,
                    ));
                  } else {
                    // Multiple pawns at same position - arrange them in a circle/stack
                    double baseLeft = LudoPath.stepBox(ludoBoard(context), coordinates[0]);
                    double baseTop = LudoPath.stepBox(ludoBoard(context), coordinates[1]);
                    double pawnSize = boxStepSize(context);
                    double offset = pawnSize * 0.15; // Offset for stacking
                    
                    playersPawn.addAll(
                      List.generate(
                        pawnsValue.length,
                        (index) {
                          var e = pawnsValue[index];
                          // Calculate position in a circular/stacked arrangement
                          double xOffset = 0;
                          double yOffset = 0;
                          
                          // For 2 pawns: side by side
                          if (pawnsValue.length == 2) {
                            xOffset = offset * (index == 0 ? -1 : 1);
                            yOffset = 0;
                          }
                          // For 3 pawns: triangle arrangement
                          else if (pawnsValue.length == 3) {
                            xOffset = offset * 1.5 * (index == 0 ? 0 : (index == 1 ? -1 : 1));
                            yOffset = offset * 1.5 * (index == 0 ? -1 : 0.5);
                          }
                          // For 4 pawns: square arrangement
                          else if (pawnsValue.length == 4) {
                            xOffset = offset * 1.5 * (index % 2 == 0 ? -1 : 1);
                            yOffset = offset * 1.5 * (index < 2 ? -1 : 1);
                          }
                          
                          return Stack(
                            key: ValueKey("${e.type.name}_${e.index}"),
                            children: [
                              AnimatedPositioned(
                                key: ValueKey("pos_${e.type.name}_${e.index}"),
                                duration: const Duration(milliseconds: 200),
                                left: baseLeft + xOffset,
                                top: baseTop + yOffset,
                                width: pawnSize * 0.85,
                                height: pawnSize * 0.85,
                                child: Transform.rotate(
                                  angle: index * 0.1, // Slight rotation for visual effect
                                  child: pawnsValue[index],
                                ),
                              ),
                              // Count badge to show multiple pawns
                              if (index == 0 && pawnsValue.length > 1)
                                Positioned(
                                  left: baseLeft + xOffset + pawnSize * 0.6,
                                  top: baseTop + yOffset - 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${pawnsValue.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    );
                  }
                }
              }

              return Center(
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    ...playersPawn,
                    ...winners(context, value.winners),
                    turnIndicator(context, value.currentPlayer.type,
                        value.currentPlayer.color, value.gameState),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget turnIndicator(BuildContext context, LudoPlayerType turn, Color color,
      LudoGameState stage) {
    int x = 0;
    int y = 0;

    switch (turn) {
      case LudoPlayerType.green:
        x = 0;
        y = 0;
        break;
      case LudoPlayerType.yellow:
        x = 1;
        y = 0;
        break;
      case LudoPlayerType.blue:
        x = 1;
        y = 1;
        break;
      case LudoPlayerType.red:
        x = 0;
        y = 1;
        break;
    }

    String stageText = "Roll the dice";
    switch (stage) {
      case LudoGameState.throwDice:
        stageText = "Roll the dice";
        break;
      case LudoGameState.moving:
        stageText = "Pawn is moving...";
        break;
      case LudoGameState.pickPawn:
        stageText = "Pick a pawn";
        break;
      case LudoGameState.finish:
        stageText = "Game is over";
        break;
    }

    return Positioned(
      top: y == 0 ? 0 : null,
      left: x == 0 ? 0 : null,
      right: x == 1 ? 0 : null,
      bottom: y == 1 ? 0 : null,
      width: ludoBoard(context) * .4,
      height: ludoBoard(context) * .4,
      child: IgnorePointer(
        child: Padding(
          padding: EdgeInsets.all(boxStepSize(context)),
          child: Container(
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(15)),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                    style: TextStyle(fontSize: 8, color: color),
                    children: [
                      const TextSpan(
                          text: "Your turn!\n",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      TextSpan(
                          text: stageText,
                          style: const TextStyle(color: Colors.black)),
                    ]),
              )),
        ),
      ),
    );
  }

  List<Widget> winners(BuildContext context, List<LudoPlayerType> winners) =>
      List.generate(
        winners.length,
        (index) {
          Widget crownImage;
          if (index == 0) {
            crownImage =
                Image.asset("assets/images/crown/1st.png", fit: BoxFit.cover);
          } else if (index == 1) {
            crownImage =
                Image.asset("assets/images/crown/2nd.png", fit: BoxFit.cover);
          } else if (index == 2) {
            crownImage =
                Image.asset("assets/images/crown/3rd.png", fit: BoxFit.cover);
          } else {
            return Container();
          }

          int x = 0;
          int y = 0;

          switch (winners[index]) {
            case LudoPlayerType.green:
              x = 0;
              y = 0;
              break;
            case LudoPlayerType.yellow:
              x = 1;
              y = 0;
              break;
            case LudoPlayerType.blue:
              x = 1;
              y = 1;
              break;
            case LudoPlayerType.red:
              x = 0;
              y = 1;
              break;
          }

          return Positioned(
            top: y == 0 ? 0 : null,
            left: x == 0 ? 0 : null,
            right: x == 1 ? 0 : null,
            bottom: y == 1 ? 0 : null,
            width: ludoBoard(context) * .4,
            height: ludoBoard(context) * .4,
            child: Padding(
              padding: EdgeInsets.all(boxStepSize(context)),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(15)),
                child: crownImage,
              ),
            ),
          );
        },
      );
}

class GameScreen extends StatefulWidget {
  final String matchId;
  final String userId;
  final List<Map<String, dynamic>> players;
  final int playersRequired;

  const GameScreen({
    super.key,
    required this.matchId,
    required this.userId,
    required this.players,
    this.playersRequired = 4,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Store player data in a list for easier access
  List<Map<String, dynamic>> gamePlayers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    context.read<Ludo>().startGame(
      playerCount: widget.playersRequired,
      matchId: widget.matchId,
      userId: widget.userId,
      playerList: widget.players,
    );
    _initializePlayers();
  }

  void _initializePlayers() {
    // Assign player data based on the order received in the 'players' list
    // and potentially their LudoPlayerType (color) if available in the data.
    // For simplicity, we'll assume the order in the list corresponds to positions.
    // You might need to adjust this logic based on how your API provides player order/color.

    // Find the logged-in user
    final currentUserData = widget.players.firstWhere(
        (player) => player['id'].toString() == widget.userId,
        orElse: () => {
              'id': widget.userId,
              'name': 'You',
              'profilePic':
                  'https://img.freepik.com/free-vector/blue-circle-with-white-user_78370-4707.jpg',
              'color': 'red' // Assuming the logged-in user is red by default
            });

    gamePlayers.add(currentUserData);

    // Add other players
    for (var player in widget.players) {
      if (player['id'].toString() != widget.userId) {
        gamePlayers.add(player);
      }
    }

    // Fill with placeholders - 4 slots for UI (2v2 shows 2 real + 2 empty)
    while (gamePlayers.length < 4) {
      gamePlayers.add({
        'id': 'empty_${gamePlayers.length}',
        'name': '',
        'profilePic': '',
        'color': 'grey',
      });
    }

    isLoading = false;
    // Trigger a rebuild to display the player data
    setState(() {});
  }

  // Helper function to fix profile picture URLs (copied from MatchingScreen)
  // Helper function to fix profile picture URLs
  String _fixProfilePictureUrl(String url) {
    // If the URL already starts with the full domain, return it as is.
    if (url.startsWith('https://ludo.eventsystem.online')) {
      return url;
    }
    // If the URL starts with a relative path like '/storage/profile/',
    // prepend the base URL.
    if (url.startsWith('/')) {
      // Assuming ConstRes.base is your base domain like 'https://ludo.eventsystem.online'
      return '${ConstRes.base}$url';
    }
    // If the URL is something else, return it as is (might be a full URL from a different source)
    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gamePlayers.length < 2) {
      return const Center(
          child: Text("Not enough players to start game."));
    }

    // 2v2: Green(bottom-left)=P1, Red(bottom-right)=P4; Yellow,Blue empty
    // 4v4: all 4 positions filled
    final is2v2 = widget.playersRequired == 2;
    final p1 = gamePlayers[0];
    final p2 = is2v2 ? (gamePlayers[2]) : gamePlayers[1]; // Yellow
    final p3 = is2v2 ? (gamePlayers[3]) : gamePlayers[2]; // Blue
    final p4 = is2v2 ? gamePlayers[1] : gamePlayers[3];   // Red

    return Scaffold(
      backgroundColor: Colors.purple.withOpacity(0.9),
      body: Stack(
        children: [
          // Main game content layer
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: BoardWidget(),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: DiceWidget(),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Match ID: ${widget.matchId}\n'
                  'User ID: ${widget.userId}\n'
                  'Mode: ${widget.playersRequired}v${widget.playersRequired}\n'
                  'Players: ${gamePlayers.where((p) => (p['name'] ?? '').toString().isNotEmpty).map((p) => p['name']).join(', ')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Consumer<Ludo>(
                builder: (context, value, child) {
                  // Ab game turant end ho jayega jab koi bhi ek player jeet jaye
                  final isGameOver = value.winners.isNotEmpty;
                  if (isGameOver) {
                    return Container(
                      color: Colors.black.withOpacity(0.8),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset("assets/images/thankyou.gif"),
                            const Text(
                              "Thank you for playing 😙",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              "The Winners are: ${value.winners.map((e) => e.name.toUpperCase()).join(", ")}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 30),
                              textAlign: TextAlign.center,
                            ),
                            const Divider(color: Colors.white),
                            const Text(
                              "This game was made with Flutter ❤ by Mochamad Aryan Raikwar",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Refresh your browser to play again",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
          // Player profiles overlay layer
          Consumer<Ludo>(
            builder: (context, ludo, child) {
              final currentTurn = ludo.currentPlayer.type;
              return Positioned.fill(
                child: Stack(
                  children: [
                    // Player 1 (Green) - Bottom Left
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: _buildUserProfile(
                        p1['name'] ?? 'You',
                        _fixProfilePictureUrl((p1['profilePic'] ?? '') as String)
                            .isEmpty ? '${ConstRes.base}/storage/profile/profile.png'
                            : _fixProfilePictureUrl(p1['profilePic'] as String),
                        playerColor: LudoPlayerType.green,
                        isCurrentTurn: currentTurn == LudoPlayerType.green,
                      ),
                    ),
                    // Player 2 (Yellow) - Top Left
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _buildUserProfile(
                        p2['name'] ?? (is2v2 ? '' : 'Player 2'),
                        _fixProfilePictureUrl((p2['profilePic'] ?? '') as String)
                            .isEmpty ? '${ConstRes.base}/storage/profile/profile.png'
                            : _fixProfilePictureUrl(p2['profilePic'] as String),
                        isEmpty: is2v2,
                        playerColor: LudoPlayerType.yellow,
                        isCurrentTurn: currentTurn == LudoPlayerType.yellow,
                      ),
                    ),
                    // Player 3 (Blue) - Top Right
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildUserProfile(
                        p3['name'] ?? (is2v2 ? '' : 'Player 3'),
                        _fixProfilePictureUrl((p3['profilePic'] ?? '') as String)
                            .isEmpty ? '${ConstRes.base}/storage/profile/profile.png'
                            : _fixProfilePictureUrl(p3['profilePic'] as String),
                        isEmpty: is2v2,
                        playerColor: LudoPlayerType.blue,
                        isCurrentTurn: currentTurn == LudoPlayerType.blue,
                      ),
                    ),
                    // Player 4 (Red) - Bottom Right
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: _buildUserProfile(
                        p4['name'] ?? (is2v2 ? 'Opponent' : 'Player 4'),
                        _fixProfilePictureUrl((p4['profilePic'] ?? '') as String)
                            .isEmpty ? '${ConstRes.base}/storage/profile/profile.png'
                            : _fixProfilePictureUrl(p4['profilePic'] as String),
                        playerColor: LudoPlayerType.red,
                        isCurrentTurn: currentTurn == LudoPlayerType.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Board vars overlay - sabse upar taaki dikhe
          const Positioned(
            top: 10,
            left: 10,
            child: BoardVarsOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfile(String username, String imageUrl, {
    bool isEmpty = false,
    LudoPlayerType? playerColor,
    bool isCurrentTurn = false,
  }) {
    if (isEmpty || username.isEmpty) {
      return Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text('—', style: TextStyle(color: Colors.grey[600], fontSize: 24)),
      );
    }
    
    // Get color based on player type and turn
    Color cardColor = Colors.grey[500]!;
    Color borderColor = Colors.grey.shade600;
    
    if (isCurrentTurn && playerColor != null) {
      switch (playerColor) {
        case LudoPlayerType.green:
          cardColor = LudoColor.green;
          borderColor = LudoColor.green;
          break;
        case LudoPlayerType.yellow:
          cardColor = LudoColor.yellow;
          borderColor = LudoColor.yellow;
          break;
        case LudoPlayerType.blue:
          cardColor = LudoColor.blue;
          borderColor = LudoColor.blue;
          break;
        case LudoPlayerType.red:
          cardColor = LudoColor.red;
          borderColor = LudoColor.red;
          break;
      }
    }
    
    return GestureDetector(
      onTap: () {
        _showUserProfileDialog(username, imageUrl);
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrentTurn ? borderColor : Colors.grey.shade600,
            width: isCurrentTurn ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrentTurn 
                  ? borderColor.withOpacity(0.6)
                  : Colors.black.withOpacity(0.5),
              blurRadius: isCurrentTurn ? 20 : 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(imageUrl),
              backgroundColor: Colors.blueAccent,
            ),
            const SizedBox(height: 4),
            Text(
              username,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, size: 18, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up,
                      size: 18, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUserProfileDialog(String username, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          title: Text("Profile of $username"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(imageUrl),
                backgroundColor: Colors.blueAccent,
              ),
              const SizedBox(height: 10),
              Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {},
                child: const Text("Add Friend"),
              ),
              const Text("Send a Gift"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.card_giftcard),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.stars),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.message),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}

/// Overlay on board screen to show variables & positions used for rendering.
class BoardVarsOverlay extends StatefulWidget {
  const BoardVarsOverlay({super.key});

  @override
  State<BoardVarsOverlay> createState() => _BoardVarsOverlayState();
}

class _BoardVarsOverlayState extends State<BoardVarsOverlay> {
  bool _visible = true;

  static double _ludoBoardSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 500) return 500;
    if (width < 300) return 300;
    return width - 20;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _visible = !_visible),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _visible ? Icons.keyboard_arrow_up : Icons.info_outline,
                    color: Colors.amberAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _visible ? 'Hide Vars' : 'Vars / Position',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_visible) ...[
            const SizedBox(height: 6),
            Consumer<Ludo>(
              builder: (context, ludo, _) {
                final boardSize = _ludoBoardSize(context);
                final boxStep = boardSize / 15;
                return Container(
                  constraints: const BoxConstraints(maxWidth: 320, maxHeight: 380),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('gameState', ludo.gameState.toString()),
                        _row('currentTurn', ludo.currentPlayer.type.toString()),
                        _row('diceResult', '${ludo.diceResult}'),
                        _row('myColor (You)', ludo.myColor?.name ?? '—'),
                        _row('boardSize', boardSize.toStringAsFixed(1)),
                        _row('boxStepSize', boxStep.toStringAsFixed(2)),
                        const Divider(color: Colors.white38, height: 16),
                        ...ludo.players.map((player) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.type.name,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              ...List.generate(player.pawns.length, (i) {
                                final p = player.pawns[i];
                                final List<double> coord = p.step < 0
                                    ? player.homePath[p.index]
                                    : player.path[p.step];
                                final left = LudoPath.stepBox(boardSize, coord[0]);
                                final top = LudoPath.stepBox(boardSize, coord[1]);
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 2),
                                  child: Text(
                                    '  P$i step=${p.step} pos=[${coord[0].toStringAsFixed(1)},${coord[1].toStringAsFixed(1)}] px=(${left.toStringAsFixed(0)},${top.toStringAsFixed(0)})',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 6),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
