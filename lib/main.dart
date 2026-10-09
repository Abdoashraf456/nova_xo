import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const NovaXOApp());

const Color cyan = Color(0xFF35E7FF);
const Color pink = Color(0xFFFF43E8);
const Color violet = Color(0xFF8B5CFF);
const Color background = Color(0xFF050714);

class NovaXOApp extends StatelessWidget {
  const NovaXOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NOVA XO',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: background,
      ),
      home: const NovaHome(),
    );
  }
}

class NovaHome extends StatefulWidget {
  const NovaHome({super.key});

  @override
  State<NovaHome> createState() => _NovaHomeState();
}

class _NovaHomeState extends State<NovaHome>
    with TickerProviderStateMixin {
  final List<String> board = List.filled(9, '');

  String mode = 'ai';
  String difficulty = 'hard';
  String turn = 'X';
  String status = 'YOUR MOVE';
  String? winner;

  bool gameOver = false;
  bool busy = false;
  bool soundOn = true;

  int wins = 0;
  int draws = 0;
  int losses = 0;
  int streak = 0;
  int bestStreak = 0;
  int games = 0;

  late final AnimationController pulse;
  late final AnimationController sweep;

  final Random random = Random();

  @override
  void initState() {
    super.initState();

    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _loadStats();
  }

  @override
  void dispose() {
    pulse.dispose();
    sweep.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final p = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      wins = p.getInt('wins') ?? 0;
      draws = p.getInt('draws') ?? 0;
      losses = p.getInt('losses') ?? 0;
      streak = p.getInt('streak') ?? 0;
      bestStreak = p.getInt('bestStreak') ?? 0;
      games = p.getInt('games') ?? 0;
    });
  }

  Future<void> _saveStats() async {
    final p = await SharedPreferences.getInstance();

    await p.setInt('wins', wins);
    await p.setInt('draws', draws);
    await p.setInt('losses', losses);
    await p.setInt('streak', streak);
    await p.setInt('bestStreak', bestStreak);
    await p.setInt('games', games);
  }

  void _newGame() {
    setState(() {
      for (int i = 0; i < 9; i++) {
        board[i] = '';
      }

      turn = 'X';
      winner = null;
      gameOver = false;
      busy = false;

      status = mode == 'ai'
          ? 'YOUR MOVE'
          : 'PLAYER X • YOUR TURN';
    });
  }

  void _tapCell(int i) {
    if (board[i].isNotEmpty || gameOver || busy) return;

    setState(() {
      board[i] = turn;
      _checkResult();

      if (!gameOver && mode == 'ai') {
        turn = 'O';
        status = 'NOVA IS THINKING...';
        busy = true;
      } else if (!gameOver) {
        turn = turn == 'X' ? 'O' : 'X';
        status = 'PLAYER $turn • YOUR TURN';
      }
    });

    if (!gameOver && mode == 'ai' && busy) {
      Future.delayed(
        const Duration(milliseconds: 480),
        _aiMove,
      );
    }
  }

  void _aiMove() {
    if (!mounted || gameOver) return;

    final empty = <int>[];

    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) {
        empty.add(i);
      }
    }

    if (empty.isEmpty) {
      setState(() {
        busy = false;
        _checkResult();
      });
      return;
    }

    int move;

    if (difficulty == 'easy') {
      move = empty[random.nextInt(empty.length)];
    } else if (difficulty == 'medium' &&
        random.nextDouble() < 0.45) {
      move = empty[random.nextInt(empty.length)];
    } else {
      move = _bestMove();
    }

    setState(() {
      board[move] = 'O';
      busy = false;

      _checkResult();

      if (!gameOver) {
        turn = 'X';
        status = 'YOUR MOVE';
      }
    });
  }

  int _bestMove() {
    int bestScore = -1000;
    int bestIndex = 4;

    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) {
        board[i] = 'O';

        final score = _minimax(false, 0);

        board[i] = '';

        if (score > bestScore) {
          bestScore = score;
          bestIndex = i;
        }
      }
    }

    return bestIndex;
  }

  int _minimax(bool maximizing, int depth) {
    final result = _winnerForSearch();

    if (result == 'O') return 10 - depth;
    if (result == 'X') return depth - 10;
    if (!board.contains('')) return 0;

    if (maximizing) {
      int best = -1000;

      for (int i = 0; i < 9; i++) {
        if (board[i].isEmpty) {
          board[i] = 'O';

          best = max(
            best,
            _minimax(false, depth + 1),
          );

          board[i] = '';
        }
      }

      return best;
    } else {
      int best = 1000;

      for (int i = 0; i < 9; i++) {
        if (board[i].isEmpty) {
          board[i] = 'X';

          best = min(
            best,
            _minimax(true, depth + 1),
          );

          board[i] = '';
        }
      }

      return best;
    }
  }

  String? _winnerForSearch() {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (final line in lines) {
      final a = board[line[0]];

      if (a.isNotEmpty &&
          a == board[line[1]] &&
          a == board[line[2]]) {
        return a;
      }
    }

    return null;
  }

  void _checkResult() {
    final result = _winnerForSearch();

    if (result != null) {
      winner = result;
      gameOver = true;
      games++;

      if (result == 'X') {
        wins++;
        streak++;
        bestStreak = max(bestStreak, streak);

        status = mode == 'ai'
            ? 'VICTORY • YOU BEAT NOVA'
            : 'PLAYER X WINS';
      } else {
        losses++;
        streak = 0;

        status = mode == 'ai'
            ? 'NOVA WINS • REMATCH?'
            : 'PLAYER O WINS';
      }

      _saveStats();
      return;
    }

    if (!board.contains('')) {
      gameOver = true;
      winner = 'draw';

      draws++;
      games++;
      streak = 0;

      status = 'DRAW • PERFECTLY MATCHED';

      _saveStats();
    }
  }

  void _selectMode(String value) {
    setState(() {
      mode = value;
    });

    _newGame();
  }

  void _selectDifficulty(String value) {
    setState(() {
      difficulty = value;
    });
  }

  void _showStats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1025),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'PLAYER PROFILE',
              style: TextStyle(
                color: cyan,
                fontSize: 18,
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _statTile('WINS', '$wins', cyan),
                const SizedBox(width: 10),
                _statTile('DRAWS', '$draws', violet),
                const SizedBox(width: 10),
                _statTile('LOSSES', '$losses', pink),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    'TOTAL MATCHES',
                    '$games',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _infoTile(
                    'BEST WIN STREAK',
                    '$bestStreak',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () async {
                final p =
                    await SharedPreferences.getInstance();

                await p.clear();

                if (!mounted) return;

                setState(() {
                  wins = 0;
                  draws = 0;
                  losses = 0;
                  streak = 0;
                  bestStreak = 0;
                  games = 0;
                });

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(
                Icons.restart_alt,
                color: pink,
              ),
              label: const Text(
                'RESET PROFILE',
                style: TextStyle(
                  color: pink,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          border: Border.all(
            color: color.withOpacity(.45),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.8, -.9),
                  radius: 1.2,
                  colors: [
                    Color(0xFF17245A),
                    background,
                    Color(0xFF090315),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -90,
            child: _orb(
              250,
              pink.withOpacity(.12),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _orb(
              280,
              cyan.withOpacity(.10),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      22,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _heroTitle(),
                        const SizedBox(height: 22),
                        _opponentCard(),
                        const SizedBox(height: 20),
                        _board(),
                        const SizedBox(height: 17),
                        _statusLine(),
                        const SizedBox(height: 18),
                        _playAgainButton(),
                        const SizedBox(height: 18),
                        _modePicker(),
                        if (mode == 'ai') ...[
                          const SizedBox(height: 15),
                          _difficultyPicker(),
                        ],
                        const SizedBox(height: 20),
                        _quickStats(),
                        const SizedBox(height: 18),
                        const Text(
                          'THINK  •  PLAY  •  CONQUER',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 90,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [cyan, violet, pink],
              ),
              boxShadow: [
                BoxShadow(
                  color: cyan.withOpacity(.2),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'NOVA XO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
          ),
          _iconButton(
            Icons.bar_chart_rounded,
            _showStats,
          ),
          const SizedBox(width: 9),
          _iconButton(
            soundOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            () {
              setState(() {
                soundOn = !soundOn;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _iconButton(
    IconData icon,
    VoidCallback action,
  ) {
    return InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.045),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(
          icon,
          color: cyan,
          size: 21,
        ),
      ),
    );
  }

  Widget _heroTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (r) {
            return const LinearGradient(
              colors: [cyan, Colors.white, pink],
            ).createShader(r);
          },
          child: const Text(
            'THE MIND ARENA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'MORE THAN A GAME. A BATTLE OF MINDS.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            letterSpacing: 2.1,
          ),
        ),
        const SizedBox(height: 13),
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) {
            return Container(
              width: 74,
              height: 2,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    cyan,
                    pink,
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: cyan.withOpacity(
                      .3 + pulse.value * .4,
                    ),
                    blurRadius: 12,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _opponentCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: violet.withOpacity(.35),
        ),
        boxShadow: [
          BoxShadow(
            color: violet.withOpacity(.06),
            blurRadius: 25,
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(Icons.smart_toy_rounded, cyan, 'NOVA'),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOVA CORE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Adaptive AI opponent',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: cyan.withOpacity(.09),
              border: Border.all(
                color: cyan.withOpacity(.4),
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              mode == 'ai'
                  ? difficulty.toUpperCase()
                  : '2 PLAYERS',
              style: const TextStyle(
                color: cyan,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(
    IconData icon,
    Color color,
    String label,
  ) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(.1),
        border: Border.all(
          color: color.withOpacity(.65),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.12),
            blurRadius: 14,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _board() {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: sweep,
        builder: (_, __) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cyan.withOpacity(.18),
                  const Color(0xFF10152D),
                  pink.withOpacity(.12),
                ],
              ),
              border: Border.all(
                color: cyan.withOpacity(
                  .34 + pulse.value * .18,
                ),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: cyan.withOpacity(
                    .07 + pulse.value * .04,
                  ),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
              ),
              itemBuilder: (context, i) => _cell(i),
            ),
          );
        },
      ),
    );
  }

  Widget _cell(int i) {
    final value = board[i];

    final isWinnerCell = winner != null &&
        winner != 'draw' &&
        _isWinningCell(i);

    final color = value == 'X' ? cyan : pink;

    return GestureDetector(
      onTap: () => _tapCell(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        decoration: BoxDecoration(
          color: isWinnerCell
              ? color.withOpacity(.20)
              : const Color(0xFF080D20).withOpacity(.94),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: value.isEmpty
                ? Colors.white.withOpacity(.09)
                : color.withOpacity(isWinnerCell ? 1 : .6),
            width: value.isEmpty ? 1 : 1.3,
          ),
          boxShadow: value.isEmpty
              ? []
              : [
                  BoxShadow(
                    color: color.withOpacity(
                      isWinnerCell ? .35 : .12,
                    ),
                    blurRadius: isWinnerCell ? 20 : 12,
                  ),
                ],
        ),
        child: Center(
          child: AnimatedScale(
            scale: value.isEmpty ? .6 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: value.isEmpty
                ? Icon(
                    Icons.add_rounded,
                    color: Colors.white.withOpacity(.07),
                    size: 23,
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: color,
                      shadows: [
                        Shadow(
                          color: color.withOpacity(.8),
                          blurRadius: 20,
                        ),
                        Shadow(
                          color: color.withOpacity(.4),
                          blurRadius: 35,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  bool _isWinningCell(int index) {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (final line in lines) {
      if (line.contains(index) &&
          board[line[0]].isNotEmpty &&
          board[line[0]] == board[line[1]] &&
          board[line[1]] == board[line[2]]) {
        return true;
      }
    }

    return false;
  }

  Widget _statusLine() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: gameOver
                ? (winner == 'X'
                    ? cyan
                    : winner == 'O'
                        ? pink
                        : violet)
                : (busy ? pink : cyan),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (gameOver ? pink : cyan).withOpacity(.8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: gameOver
                  ? (winner == 'X' ? cyan : pink)
                  : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _playAgainButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3C5CFF),
              Color(0xFF8D3DFF),
              Color(0xFFE62DDA),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: violet.withOpacity(.25),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _newGame,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
          ),
          label: const Text(
            'PLAY AGAIN',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHOOSE YOUR BATTLE',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _modeButton(
                'ai',
                Icons.smart_toy_rounded,
                'PLAY VS NOVA',
                'Challenge the AI',
                cyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _modeButton(
                'friend',
                Icons.groups_rounded,
                'TWO PLAYERS',
                'Local multiplayer',
                pink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modeButton(
    String value,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    final selected = mode == value;

    return InkWell(
      onTap: () => _selectMode(value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(.12)
              : Colors.white.withOpacity(.025),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color.withOpacity(.75)
                : Colors.white12,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(.08),
                    blurRadius: 16,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? color : Colors.white38,
              size: 25,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI THREAT LEVEL',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _difficultyButton(
              'easy',
              'EASY',
              'Warm up',
              const Color(0xFF38F2A3),
              Icons.spa_rounded,
            ),
            const SizedBox(width: 8),
            _difficultyButton(
              'medium',
              'MEDIUM',
              'Tactical',
              cyan,
              Icons.bolt_rounded,
            ),
            const SizedBox(width: 8),
            _difficultyButton(
              'hard',
              'HARD',
              'Unbeatable',
              pink,
              Icons.local_fire_department_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _difficultyButton(
    String value,
    String label,
    String sub,
    Color color,
    IconData icon,
  ) {
    final selected = difficulty == value;

    return Expanded(
      child: InkWell(
        onTap: () => _selectDifficulty(value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            vertical: 13,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(.13)
                : Colors.white.withOpacity(.025),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color.withOpacity(.8)
                  : Colors.white12,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? color : Colors.white30,
                size: 21,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickStats() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _quickStat(
            Icons.emoji_events_rounded,
            '$wins',
            'WINS',
            const Color(0xFFFFD166),
          ),
          _verticalDivider(),
          _quickStat(
            Icons.all_inclusive_rounded,
            '$draws',
            'DRAWS',
            cyan,
          ),
          _verticalDivider(),
          _quickStat(
            Icons.local_fire_department_rounded,
            '$streak',
            'STREAK',
            pink,
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white12,
    );
  }

  Widget _quickStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}