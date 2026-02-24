import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:ludo_flutter/game/game.dart';
import 'dart:math';

// Base URL for your API
const String _apiUrl = 'https://ludo.eventsystem.online/api/board';
const String _walletApiUrl = 'https://ludo.eventsystem.online/api/wallet';

class MatchingScreen extends StatefulWidget {
  final String userId;
  final String gameId;

  const MatchingScreen({super.key, required this.userId, required this.gameId});

  @override
  _MatchingScreenState createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  // State Variables
  String _userName = "Loading...";
  String _profilePicUrl = "";
  int _userCoins = 0;
  int _entryFee = 12;
  int _winningAmount = 36; // 4v4 default: 12*3; updated by _computeWinningAmount()
  bool _isLoadingUserData = true;
  bool _isSearching = false;
  bool _isCancelling = false;
  String _matchStatusMessage = 'Select entry fee and find match';
  String? _currentMatchId;
  int _searchSeconds = 0;
  final int _matchTimeoutSeconds = 90;
  int _playersRequired = 4; // 2 for 2v2, 4 for 4v4

  /// 2v2 fixed winning amount per entry (Flutter-side; 4v4 can use backend)
  static const Map<int, int> _2v2EntryToWinning = {
    12: 20,
    17: 30,
    24: 40,
    30: 50,
    36: 62,
  };

  int _computeWinningAmount() {
    if (_playersRequired == 2) {
      return _2v2EntryToWinning[_entryFee] ?? (_entryFee * 2);
    }
    return _entryFee * (_playersRequired - 1); // 4v4: entry * 3
  }

  // Match Data
  List<Map<String, dynamic>> _opponentProfiles = [];

  // Timers
  Timer? _matchmakingTimeoutTimer;
  Timer? _searchDurationTimer;
  Timer? _pollingTimer;
  Timer? _placeholderAnimationTimer;

  // Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Random for Placeholders
  int _randomPlaceholderSeed = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _setupAudio();
    _fetchUserData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _cancelAllTimers();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // --- Audio Setup ---
  Future<void> _setupAudio() async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/match_found.mp3'));
    } catch (e) {
      debugPrint('Audio loading error: $e');
    }
  }

  // --- Timer Management ---
  void _startSearchTimers() {
    _searchSeconds = 0;
    _searchDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _searchSeconds++);
    });
    _startPlaceholderTimer();
    _startMatchmakingTimeoutTimer();
  }

  void _cancelAllTimers() {
    _searchDurationTimer?.cancel();
    _pollingTimer?.cancel();
    _placeholderAnimationTimer?.cancel();
    _matchmakingTimeoutTimer?.cancel();
    _searchDurationTimer = _pollingTimer =
        _placeholderAnimationTimer = _matchmakingTimeoutTimer = null;
  }

  void _startPlaceholderTimer() {
    _randomPlaceholderSeed = _random.nextInt(100);
    _placeholderAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && _isSearching && _opponentProfiles.length < _playersRequired) {
        setState(() {
          _randomPlaceholderSeed = _random.nextInt(100);
        });
      } else if (!_isSearching || _opponentProfiles.length >= _playersRequired) {
        _placeholderAnimationTimer?.cancel();
        _placeholderAnimationTimer = null;
      }
    });
  }

  void _startMatchmakingTimeoutTimer() {
    _matchmakingTimeoutTimer =
        Timer(Duration(seconds: _matchTimeoutSeconds), () {
      if (_isSearching && mounted) {
        debugPrint('Matchmaking timer expired. Initiating cancellation...');
        _cancelMatchmaking(); // Call cancelMatchmaking on timeout
        _showErrorSnackbar('Matchmaking timed out. Please try again.');
      }
    });
  }

  // --- API Calls ---
  Future<void> _fetchUserData() async {
    final url = '$_walletApiUrl/wallet.php?user_id=${widget.userId}';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );
      if (!mounted) return;

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final user = data['user'];
        setState(() {
          _userName = user['name'] ?? 'User';
          _profilePicUrl = _fixProfilePictureUrl(user['profile_picture'] ?? '');
          _userCoins = int.tryParse(user['coin'].toString()) ?? 0;
          _isLoadingUserData = false;
        });
      } else {
        _handleApiError(data, 'Failed to load user data');
      }
    } catch (e) {
      _handleNetworkError(e, 'Network/CORS error. On Chrome/Web use mobile app or fix server CORS.');
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _findMatch() async {
    if (_isSearching) return;

    if (_userCoins < _entryFee) {
      _showErrorSnackbar('You need at least ₹$_entryFee coins to play');
      return;
    }

    setState(() {
      _isSearching = true;
      _matchStatusMessage = 'Searching for opponents...';
      _opponentProfiles = [];
    });

    _startSearchTimers(); // Start all related timers

    try {
      final url = '$_apiUrl/create_match.php';
      final Map<String, String> body = {
        'userId': widget.userId,
        'betAmount': _entryFee.toString(),
        'gameId': widget.gameId,
        'playersRequired': _playersRequired.toString(),
      };

      debugPrint('Sending request to: $url, Body: $body');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );
      debugPrint(
          'Response status: ${response.statusCode}, Body: ${response.body}');

      if (!mounted) return;

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _currentMatchId = data['matchId'].toString();

        // Always update opponentProfiles with current players from the API response
        if (data['players'] != null) {
          setState(() {
            _opponentProfiles =
                List<Map<String, dynamic>>.from(data['players']);
          });
        }

        if (data['action'] == 'created') {
          setState(() => _matchStatusMessage = 'Waiting for players...');
          _startPollingMatchStatus(_currentMatchId!);
        } else if (data['action'] == 'joined') {
          setState(() {
            _matchStatusMessage =
                '${data['playersCount'] ?? _opponentProfiles.length}/$_playersRequired players joined';
          });
          _startPollingMatchStatus(_currentMatchId!);
        } else if (data['action'] == 'matched') {
          // Directly call _matchFound if already matched
          // Ensure match data is correctly passed
          _matchFound(
              data); // Pass the whole data containing 'match' details if available
        }
      } else {
        _handleApiError(data, 'Error finding match');
        _resetMatchmaking();
      }
    } catch (e) {
      _handleNetworkError(e, 'Network error finding match');
      _resetMatchmaking();
    }
  }

  void _startPollingMatchStatus(String matchId) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isSearching) {
        timer.cancel();
        return;
      }

      try {
        final url = '$_apiUrl/check_match.php?matchId=$matchId';
        final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Poll timeout'),
        );
        final data = json.decode(response.body);

        if (!mounted) return;

        if (data['status'] == 'success') {
          final matchData = data['match'];
          if (matchData != null) {
            if (matchData['status'] == 'matched') {
              timer.cancel();
              _matchFound(matchData); // Pass the specific match data
            } else if (matchData['status'] == 'cancelled') {
              timer.cancel();
              _resetMatchmaking();
              _showErrorSnackbar('Match was cancelled.');
            } else {
              // Update players count and profiles
              setState(() {
                _opponentProfiles =
                    List<Map<String, dynamic>>.from(matchData['players'] ?? []);
                _matchStatusMessage =
                    '${matchData['playersCount'] ?? _opponentProfiles.length}/$_playersRequired players joined';
              });
            }
          } else {
            // Match data is null, possibly deleted?
            timer.cancel();
            _resetMatchmaking();
            _showErrorSnackbar('Match disappeared.');
          }
        } else {
          debugPrint('Polling check_match.php error: ${data['message']}');
          // Decide if polling should stop on error
        }
      } catch (e) {
        debugPrint('Polling network error: $e');
        // Decide if polling should stop on network error
      }
    });
  }

  Future<void> _cancelMatchmaking() async {
    if (!_isSearching || _isCancelling) return;

    setState(() => _isCancelling = true);
    _cancelAllTimers(); // Stop all timers

    try {
      if (_currentMatchId != null) {
        final url = '$_apiUrl/leave_match.php';
        final response = await http.post(
          Uri.parse(url),
          body: {'userId': widget.userId, 'matchId': _currentMatchId},
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Cancel timeout'),
        );
        debugPrint(
            'Cancel response status: ${response.statusCode}, Body: ${response.body}');

        if (!mounted) return;
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          _showSnackbar(data['message'] ?? 'Search cancelled');
        } else {
          _showErrorSnackbar(data['message'] ?? 'Failed to cancel search');
        }
      } else {
        // If currentMatchId is null, just reset UI
        _showSnackbar('Search cancelled (no active match ID)');
      }
    } catch (e) {
      _handleNetworkError(e, 'Network error during cancellation');
    } finally {
      if (mounted) {
        _resetMatchmaking(); // Always reset UI regardless of API outcome
      }
    }
  }

  // --- Match Found Logic ---
  void _matchFound(Map<String, dynamic> matchData) async {
    _cancelAllTimers(); // Stop all timers immediately

    try {
      await _audioPlayer.play(AssetSource('sounds/match_found.mp3'));
      HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('Error playing sound: $e');
      HapticFeedback.vibrate();
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
        _matchStatusMessage = 'Match Found!';
        // Ensure _opponentProfiles is updated with the final matched players
        _opponentProfiles =
            List<Map<String, dynamic>>.from(matchData['players'] ?? []);
        _currentMatchId = matchData['id'].toString();
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          // Validate we have enough players (2 for 2v2, 4 for 4v4)
          if (_opponentProfiles.length >= _playersRequired) {
            // Ensure the current user's profile is correctly included in the players list passed to GameScreen
            // The API should return the full list of 4 players including the current user.
            // We can double check or rely on the API's accuracy here.
            // Assuming API returns all 4, including the current user.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GameScreen(
                  matchId: _currentMatchId!,
                  userId: widget.userId,
                  players: _opponentProfiles,
                  playersRequired: _playersRequired,
                ),
              ),
            );
          } else {
            // Unexpected state: match status is 'matched' but players list is not 4
            debugPrint('Error: Match found but players list is not 4.');
            _resetMatchmaking();
            _showErrorSnackbar(
                'Match data error. Please try finding match again.');
          }
        }
      });
    }
  }

  // --- UI State Reset ---
  void _resetMatchmaking() {
    if (mounted) {
      setState(() {
        _isSearching = false;
        _isCancelling = false;
        _currentMatchId = null;
        _matchStatusMessage = 'Select entry fee and find match';
        _opponentProfiles = [];
        _searchSeconds = 0;
      });
    }
    _cancelAllTimers(); // Ensure all timers are stopped
  }

  // --- Utility Functions ---
  void _handleApiError(Map<String, dynamic> data, String defaultMessage) {
    debugPrint('API Error: ${data['message']}');
    _showErrorSnackbar(data['message'] ?? defaultMessage);
  }

  void _handleNetworkError(dynamic e, String defaultMessage) {
    debugPrint('Network/Other Error: $e');
    _showErrorSnackbar(defaultMessage);
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  String _fixProfilePictureUrl(String url) {
    if (url.startsWith('https://ludo.eventsystem.onlinehttps://')) {
      return url.replaceFirst('https://ludo.eventsystem.online', '');
    }
    try {
      Uri uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return '';
      }
    } catch (e) {
      return '';
    }
    return url;
  }

  String get _formattedSearchTime {
    final minutes = (_searchSeconds / 60).floor();
    final seconds = _searchSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    // Prepare the list of profiles to display, ensuring current user is first when searching
    List<Map<String, dynamic>> displayProfiles = [];
    if (_isSearching) {
      // Add current user first
      displayProfiles.add({
        'id': widget.userId,
        'name': _userName,
        'profilePic': _profilePicUrl,
        'isReady': 1, // Assume user is ready when searching
      });
      // Add other found players, excluding current user if duplicated
      for (var profile in _opponentProfiles) {
        if (profile['id'].toString() != widget.userId) {
          displayProfiles.add(profile);
        }
      }
      // Add placeholders (2 for 2v2, 4 for 4v4)
      while (displayProfiles.length < _playersRequired) {
        displayProfiles.add({}); // Empty map for placeholder
      }
    } else {
      // If not searching, use only the required number of players (2 for 2v2, 4 for 4v4)
      displayProfiles = _opponentProfiles.length >= _playersRequired
          ? _opponentProfiles.sublist(0, _playersRequired)
          : List<Map<String, dynamic>>.from(_opponentProfiles);
    }

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (_isSearching) {
          final confirmCancel = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Search?'),
              content: const Text(
                  'Are you sure you want to cancel the match search?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No')),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes')),
              ],
            ),
          );
          if (confirmCancel == true && context.mounted) {
            await _cancelMatchmaking();
            if (context.mounted) Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ludo Matchmaking'),
          backgroundColor: Colors.deepPurple,
        ),
        body: _isLoadingUserData
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // Use stretch for full width
                  children: [
                    // User Profile Card
                    _buildUserProfileCard(),
                    const SizedBox(height: 20),

                    // Match Mode: 2v2 or 4v4
                    _buildMatchModeSelection(),
                    const SizedBox(height: 20),

                    // Bet Selection
                    _buildBetSelection(),
                    const SizedBox(height: 20),

                    // Prize Pool Display
                    _buildPrizePoolDisplay(),
                    const SizedBox(height: 20),

                    // Match Status
                    _buildMatchStatus(),
                    const SizedBox(height: 20),

                    // Players Row / Searching Placeholder Row
                    _buildPlayersDisplay(displayProfiles),
                    const SizedBox(height: 20),

                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(
                _profilePicUrl.isNotEmpty
                    ? _profilePicUrl
                    : 'https://i.pravatar.cc/150?img=3',
              ),
              backgroundColor: Colors.grey.shade200,
              onBackgroundImageError: (e, stack) =>
                  debugPrint('Failed to load user profile image: $e'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text('$_userCoins coins',
                          style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text('Match Mode:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('2v2'),
                selected: _playersRequired == 2,
                onSelected: (_) {
                  if (!_isSearching) {
                    setState(() {
                      _playersRequired = 2;
                      _winningAmount = _computeWinningAmount();
                    });
                  }
                },
                selectedColor: Colors.deepPurple,
                labelStyle: TextStyle(
                    color: _playersRequired == 2 ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('4v4'),
                selected: _playersRequired == 4,
                onSelected: (_) {
                  if (!_isSearching) {
                    setState(() {
                      _playersRequired = 4;
                      _winningAmount = _computeWinningAmount(); // 4v4: entry*3 (or backend later)
                    });
                  }
                },
                selectedColor: Colors.deepPurple,
                labelStyle: TextStyle(
                    color: _playersRequired == 4 ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBetSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text('Select Entry Fee:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        Wrap(
          spacing: 10,
          children: [12, 17, 24, 30, 36].map((fee) {
            return ChoiceChip(
              label: Text('₹$fee'),
              selected: _entryFee == fee,
              onSelected: (_) {
                if (!_isSearching) {
                  setState(() {
                    _entryFee = fee;
                    _winningAmount = _computeWinningAmount();
                  });
                }
              },
              selectedColor: Colors.deepPurple,
              labelStyle: TextStyle(
                  color: _entryFee == fee ? Colors.white : Colors.black),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrizePoolDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.deepPurple.shade100, Colors.deepPurple.shade200]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.deepPurple.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text('Winning Amount',
              style:
                  TextStyle(fontSize: 16, color: Colors.deepPurple.shade800)),
          const SizedBox(height: 8),
          Text('₹$_winningAmount',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade900)),
          const SizedBox(height: 4),
          Text('(Total Entry: ₹${_entryFee * _playersRequired})',
              style:
                  TextStyle(fontSize: 14, color: Colors.deepPurple.shade700)),
        ],
      ),
    );
  }

  Widget _buildMatchStatus() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_matchStatusMessage + _searchSeconds.toString()),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: _matchStatusMessage.contains('Found')
              ? Colors.green.shade100
              : Colors.deepPurple.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSearching && !_matchStatusMessage.contains('Found'))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.deepPurple)),
                ),
              ),
            Flexible(
              child: Text(
                _isSearching
                    ? '$_matchStatusMessage ($_formattedSearchTime)'
                    : _matchStatusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _matchStatusMessage.contains('Found')
                      ? Colors.green.shade800
                      : Colors.deepPurple.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersDisplay(List<Map<String, dynamic>> displayProfiles) {
    return Column(
      children: [
        Text(
          _isSearching ? 'Finding Players...' : 'Players',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _isSearching ? Colors.deepPurple.shade700 : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_playersRequired, (index) {
            final player =
                index < displayProfiles.length ? displayProfiles[index] : null;
            // Pass the random seed to the PlayerCard
            return Expanded(
              child: PlayerCard(
                player: player,
                isCurrentUser: player != null
                    ? player['id'].toString() == widget.userId
                    : false,
                isSearching: _isSearching,
                randomPlaceholderSeed: _randomPlaceholderSeed, // Pass the seed
                placeholderIndex: index, // Pass the index for placeholder image
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSearching ? null : _findMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isSearching ? Icons.search_off : Icons.search,
                    color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _isSearching ? 'Searching...' : 'Find Match',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCancelling ? null : _cancelMatchmaking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isCancelling ? 'Cancelling...' : 'Cancel Search',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- Extracted Player Card Widget ---
class PlayerCard extends StatelessWidget {
  final Map<String, dynamic>? player;
  final bool isCurrentUser;
  final bool isSearching;
  final int randomPlaceholderSeed; // Receive the seed
  final int placeholderIndex; // Receive the index

  const PlayerCard({
    super.key,
    required this.player,
    required this.isCurrentUser,
    required this.isSearching,
    required this.randomPlaceholderSeed,
    required this.placeholderIndex,
  });

  String _fixProfilePictureUrl(String url) {
    if (url.startsWith('https://ludo.eventsystem.onlinehttps://')) {
      return url.replaceFirst('https://ludo.eventsystem.online', '');
    }
    try {
      Uri uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return '';
      }
    } catch (e) {
      return '';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final String playerName =
        player?['name'] ?? (isCurrentUser ? 'You' : 'Finding...');
    final String playerProfilePic = player?['profilePic'] ?? '';
    final bool isReady = player?['isReady'] == 1;

    final String imageUrl = _fixProfilePictureUrl(playerProfilePic);
    final String displayImageUrl = imageUrl.isNotEmpty
        ? imageUrl
        : 'https://i.pravatar.cc/150?img=${placeholderIndex + 1 + randomPlaceholderSeed}'; // Use passed seed and index

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(displayImageUrl),
                  onBackgroundImageError: (e, stack) {
                    debugPrint('Failed to load image $displayImageUrl: $e');
                  },
                  backgroundColor: Colors.grey.shade200,
                ),
                if (isSearching && !isCurrentUser && player == null)
                  Positioned.fill(
                    child: ClipOval(
                      child: CustomPaint(
                        // Use a simple animation based on time or a controller if more complex needed
                        painter: PulsatingCirclePainter(
                            animationValue:
                                (DateTime.now().millisecondsSinceEpoch % 1000) /
                                    1000.0, // Simple time-based animation
                            color: Colors.deepPurple.withOpacity(0.3)),
                      ),
                    ),
                  ),
                if (isCurrentUser)
                  Positioned(
                    bottom: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('You',
                          style: TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              playerName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: isCurrentUser ? Colors.deepPurple : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (isReady)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle, color: Colors.green, size: 12),
              ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the pulsating circle effect (remains the same)
class PulsatingCirclePainter extends CustomPainter {
  // Note: Using a simple time-based animation here.
  // For smoother, controller-driven animation, you'd pass an Animation<double>
  // from an AnimationController to this painter.
  final double animationValue;
  final Color color;

  PulsatingCirclePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Simple pulsating effect
    final currentRadius = maxRadius * (0.5 + 0.5 * (1 - animationValue));
    final opacity = 1.0 - animationValue;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant PulsatingCirclePainter oldDelegate) {
    // Repaint if animation value or color changes
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
