
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bg = Color(0xFF070B18);
const cyan = Color(0xFF00F5FF);
const pink = Color(0xFFFF3CAC);
const purple = Color(0xFF8B5CF6);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovaXO());
}

class NovaXO extends StatelessWidget {
  const NovaXO({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NOVA XO',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cyan,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with TickerProviderStateMixin {
  final AudioPlayer _audio = AudioPlayer();
  final math.Random _random = math.Random();

  List<String> board = List.filled(9, '');
  bool vsComputer = true;
  bool soundOn = true;
  bool busy = false;
  bool gameOver = false;

  // X is the human player. O is the computer or second player.
  String current = 'X';
  String startingPlayer = 'X';
  String difficulty = 'متوسط';

  String status = 'دورك يا بطل!';
  List<int> winningCells = [];

  int xScore = 0;
  int oScore = 0;
  int draws = 0;
  int rounds = 0;

  late final AnimationController _pulse;
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      xScore = prefs.getInt('nova_x_score') ?? 0;
      oScore = prefs.getInt('nova_o_score') ?? 0;
      draws = prefs.getInt('nova_draws') ?? 0;
      rounds = prefs.getInt('nova_rounds') ?? 0;
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nova_x_score', xScore);
    await prefs.setInt('nova_o_score', oScore);
    await prefs.setInt('nova_draws', draws);
    await prefs.setInt('nova_rounds', rounds);
  }

  // Generate a small WAV sound directly in Dart. No audio asset files needed.
  Uint8List _makeTone({
    required double frequency,
    required int milliseconds,
    double volume = 0.25,
  }) {
    const sampleRate = 22050;
    const channels = 1;
    const bitsPerSample = 16;

    final sampleCount =
        (sampleRate * milliseconds / 1000).round();
    final dataSize = sampleCount * 2;
    final bytes = ByteData(44 + dataSize);

    void writeText(int offset, String text) {
      for (int i = 0; i < text.length; i++) {
        bytes.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    writeText(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * channels * 2, Endian.little);
    bytes.setUint16(32, channels * 2, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeText(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < sampleCount; i++) {
      final progress = i / sampleCount;
      final fadeIn = math.min(1.0, progress * 25);
      final fadeOut = math.min(1.0, (1 - progress) * 12);
      final envelope = math.min(fadeIn, fadeOut);
      final wave = math.sin(
        2 * math.pi * frequency * i / sampleRate,
      );
      final sample =
          (wave * volume * envelope * 32767).round();

      bytes.setInt16(
        44 + i * 2,
        sample.clamp(-32768, 32767),
        Endian.little,
      );
    }

    return bytes.buffer.asUint8List();
  }

  Future<void> _tone(
    double frequency, {
    int duration = 100,
    double volume = 0.22,
  }) async {
    if (!soundOn) return;

    try {
      await _audio.stop();
      await _audio.play(
        BytesSource(
          _makeTone(
            frequency: frequency,
            milliseconds: duration,
            volume: volume,
          ),
        ),
      );
    } catch (_) {
      // The game still works if the device cannot play audio.
    }
  }

  Future<void> _melody(List<double> notes) async {
    if (!soundOn) return;

    for (final note in notes) {
      await _tone(note, duration: 150, volume: 0.20);
      await Future.delayed(const Duration(milliseconds: 45));
    }
  }

  void _tapSound() {
    _tone(620, duration: 65, volume: 0.16);
  }

  List<List<int>> get _wins => const [
        [0, 1, 2],
        [3, 4, 5],
        [6, 7, 8],
        [0, 3, 6],
        [1, 4, 7],
        [2, 5, 8],
        [0, 4, 8],
        [2, 4, 6],
      ];

  String? _winner(List<String> cells) {
    for (final line in _wins) {
      if (cells[line[0]].isNotEmpty &&
          cells[line[0]] == cells[line[1]] &&
          cells[line[1]] == cells[line[2]]) {
        return cells[line[0]];
      }
    }
    return null;
  }

  void _playCell(int index) {
    if (busy || gameOver || board[index].isNotEmpty) return;
    if (vsComputer && current == 'O') return;

    _tapSound();

    setState(() {
      board[index] = current;
    });

    _checkResult();

    if (!gameOver) {
      setState(() {
        current = current == 'X' ? 'O' : 'X';
        status = vsComputer
            ? (current == 'X' ? 'دورك يا بطل!' : 'الكمبيوتر بيفكر...')
            : 'دور اللاعب ${current == 'X' ? 'الأول' : 'التاني'}';
      });

      if (vsComputer && current == 'O' && !gameOver) {
        _computerTurn();
      }
    }
  }

  Future<void> _computerTurn() async {
    busy = true;
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || gameOver) {
      busy = false;
      return;
    }

    final move = _chooseComputerMove();

    if (move != -1 && board[move].isEmpty) {
      await _tone(400, duration: 85, volume: 0.16);

      if (!mounted) return;

      setState(() {
        board[move] = 'O';
      });

      _checkResult();

      if (!gameOver) {
        setState(() {
          current = 'X';
          status = 'دورك يا بطل!';
        });
      }
    }

    busy = false;
  }

  int _chooseComputerMove() {
    final empty = <int>[];
    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) empty.add(i);
    }

    if (empty.isEmpty) return -1;

    // Easy: random move.
    if (difficulty == 'سهل') {
      return empty[_random.nextInt(empty.length)];
    }

    // Medium: take a win, block the player, otherwise prefer the center.
    if (difficulty == 'متوسط') {
      for (final i in empty) {
        board[i] = 'O';
        final wins = _winner(board) == 'O';
        board[i] = '';
        if (wins) return i;
      }

      for (final i in empty) {
        board[i] = 'X';
        final danger = _winner(board) == 'X';
        board[i] = '';
        if (danger) return i;
      }

      if (board[4].isEmpty) return 4;
      final corners = [0, 2, 6, 8]
          .where((i) => board[i].isEmpty)
          .toList();

      if (corners.isNotEmpty) {
        return corners[_random.nextInt(corners.length)];
      }
      return empty[_random.nextInt(empty.length)];
    }

    // Hard: minimax, making the computer unbeatable.
    int bestScore = -9999;
    int bestMove = empty.first;

    for (final i in empty) {
      board[i] = 'O';
      final score = _minimax(board, false, 0);
      board[i] = '';

      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }
    return bestMove;
  }

  int _minimax(List<String> cells, bool maximizing, int depth) {
    final winner = _winner(cells);

    if (winner == 'O') return 10 - depth;
    if (winner == 'X') return depth - 10;
    if (!cells.contains('')) return 0;

    if (maximizing) {
      int best = -9999;

      for (int i = 0; i < 9; i++) {
        if (cells[i].isEmpty) {
          cells[i] = 'O';
          best = math.max(best, _minimax(cells, false, depth + 1));
          cells[i] = '';
        }
      }
      return best;
    } else {
      int best = 9999;

      for (int i = 0; i < 9; i++) {
        if (cells[i].isEmpty) {
          cells[i] = 'X';
          best = math.min(best, _minimax(cells, true, depth + 1));
          cells[i] = '';
        }
      }
      return best;
    }
  }

  Future<void> _checkResult() async {
    final winner = _winner(board);

    if (winner != null) {
      final line = _wins.firstWhere(
        (line) =>
            board[line[0]] == winner &&
            board[line[1]] == winner &&
            board[line[2]] == winner,
      );

      setState(() {
        gameOver = true;
        winningCells = line;
        rounds++;

        if (winner == 'X') {
          xScore++;
          status = vsComputer
              ? '🔥 كسبت يا أسطورة!'
              : '🏆 اللاعب الأول كسب!';
        } else {
          oScore++;
          status = vsComputer
              ? '🤖 الكمبيوتر كسب الجولة!'
              : '🏆 اللاعب التاني كسب!';
        }
      });

      await _saveStats();

      if (winner == 'X') {
        _melody([523, 659, 784, 1046]);
      } else {
        _melody([440, 370, 294]);
      }

      return;
    }

    if (!board.contains('')) {
      setState(() {
        gameOver = true;
        draws++;
        rounds++;
        status = '🤝 تعادل! جولة قوية';
      });

      await _saveStats();
      _melody([500, 500, 500]);
    }
  }

  // Winner of the previous round starts the next round.
  // If the previous round was a draw, the same starting player starts again.
  void _nextRound() {
    final previousWinner = _winner(board);

    setState(() {
      if (previousWinner != null) {
        startingPlayer = previousWinner;
      }

      board = List.filled(9, '');
      current = startingPlayer;
      winningCells = [];
      gameOver = false;
      busy = false;

      status = vsComputer
          ? (current == 'X' ? 'دورك يا بطل!' : 'الكمبيوتر بيبدأ...')
          : 'دور اللاعب ${current == 'X' ? 'الأول' : 'التاني'}';
    });

    if (vsComputer && current == 'O') {
      _computerTurn();
    }
  }

  void _resetStats() {
    setState(() {
      xScore = 0;
      oScore = 0;
      draws = 0;
      rounds = 0;
      board = List.filled(9, '');
      winningCells = [];
      current = 'X';
      startingPlayer = 'X';
      gameOver = false;
      busy = false;
      status = 'دورك يا بطل!';
    });
    _saveStats();
    _tone(700);
  }

  void _changeMode(bool computer) {
    setState(() {
      vsComputer = computer;
      board = List.filled(9, '');
      winningCells = [];
      current = 'X';
      startingPlayer = 'X';
      gameOver = false;
      busy = false;
      status = computer ? 'دورك يا بطل!' : 'دور اللاعب الأول';
    });
    _tone(700);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _intro.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _NeonBackground()),
          SafeArea(
            child: FadeTransition(
              opacity: _intro,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _intro,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 34,
                        ),
                        child: Column(
                          children: [
                            _topBar(),
                            const SizedBox(height: 22),
                            _heading(),
                            const SizedBox(height: 22),
                            _scoreBoard(),
                            const SizedBox(height: 20),
                            _modeSelector(),
                            const SizedBox(height: 14),
                            if (vsComputer) _difficultySelector(),
                            const SizedBox(height: 20),
                            _gameBoard(),
                            const SizedBox(height: 18),
                            _statusPanel(),
                            const SizedBox(height: 18),
                            _actionButtons(),
                            const SizedBox(height: 20),
                            const Text(
                              'N O V A   X O   •   ENTER THE ARENA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [cyan, purple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: cyan.withOpacity(0.22),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: bg,
                size: 25,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'NOVA',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _roundIcon(
              icon: soundOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: soundOn ? cyan : Colors.white38,
              onTap: () {
                setState(() => soundOn = !soundOn);
                if (soundOn) _tone(700);
              },
            ),
            const SizedBox(width: 8),
            _roundIcon(
              icon: Icons.restart_alt_rounded,
              color: pink,
              onTap: _resetStats,
            ),
          ],
        ),
      ],
    );
  }

  Widget _roundIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }

  Widget _heading() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return Text(
              'NOVA XO',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: cyan.withOpacity(0.35 + _pulse.value * 0.3),
                    blurRadius: 22,
                  ),
                  Shadow(
                    color: pink.withOpacity(0.25),
                    blurRadius: 35,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 7),
        const Text(
          'THE NEON BATTLE BEGINS',
          style: TextStyle(
            color: cyan,
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _scoreBoard() {
    return Row(
      children: [
        Expanded(
          child: _scoreCard(
            title: vsComputer ? 'أنت • X' : 'اللاعب الأول • X',
            score: xScore,
            color: cyan,
            symbol: 'X',
            active: !gameOver && current == 'X',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _scoreCard(
            title: 'تعادل',
            score: draws,
            color: Colors.white70,
            symbol: '＝',
            active: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _scoreCard(
            title: vsComputer ? 'الكمبيوتر • O' : 'اللاعب الثاني • O',
            score: oScore,
            color: pink,
            symbol: 'O',
            active: !gameOver && current == 'O',
          ),
        ),
      ],
    );
  }

  Widget _scoreCard({
    required String title,
    required int score,
    required Color color,
    required String symbol,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(active ? 0.11 : 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(active ? 0.75 : 0.20),
          width: active ? 1.5 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 18)]
            : [],
      ),
      child: Column(
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF10172B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              '🤖  ضد الكمبيوتر',
              vsComputer,
              () => _changeMode(true),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _modeButton(
              '👥  لاعبين',
              !vsComputer,
              () => _changeMode(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? cyan.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? cyan.withOpacity(0.6) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? cyan : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _difficultySelector() {
    return Row(
      children: [
        const Text(
          'الصعوبة',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 12),
        ...['سهل', 'متوسط', 'صعب'].map((level) {
          final selected = difficulty == level;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  setState(() {
                    difficulty = level;
                    board = List.filled(9, '');
                    current = 'X';
                    startingPlayer = 'X';
                    gameOver = false;
                    busy = false;
                    winningCells = [];
                    status = 'دورك يا بطل!';
                  });
                  _tone(700);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? purple.withOpacity(0.2)
                        : Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? purple : Colors.white12,
                    ),
                  ),
                  child: Text(
                    level,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _gameBoard() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1426),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cyan.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: cyan.withOpacity(0.07),
              blurRadius: 28,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: purple.withOpacity(0.06),
              blurRadius: 45,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final value = board[index];
            final isWinner = winningCells.contains(index);
            final color = value == 'X' ? cyan : pink;

            return InkWell(
              onTap: () => _playCell(index),
              borderRadius: BorderRadius.circular(17),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: isWinner
                      ? color.withOpacity(0.20)
                      : const Color(0xFF141C30),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: isWinner
                        ? color
                        : value.isNotEmpty
                            ? color.withOpacity(0.5)
                            : Colors.white.withOpacity(0.07),
                    width: isWinner ? 2 : 1,
                  ),
                  boxShadow: isWinner
                      ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 20)]
                      : [],
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: value.isEmpty ? 0.65 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.elasticOut,
                    child: AnimatedOpacity(
                      opacity: value.isEmpty ? 0 : 1,
                      duration: const Duration(milliseconds: 140),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 51,
                          fontWeight: FontWeight.w900,
                          color: color,
                          shadows: [
                            Shadow(color: color.withOpacity(0.7), blurRadius: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusPanel() {
    final isX = current == 'X';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: (gameOver ? purple : (isX ? cyan : pink))
            .withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: (gameOver ? purple : (isX ? cyan : pink))
              .withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            gameOver
                ? 'الجولة رقم $rounds • العب جولة جديدة!'
                : 'الدور الحالي: ${current == 'X' ? 'X' : 'O'}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _nextRound,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('جولة جديدة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: bg,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                board = List.filled(9, '');
                winningCells = [];
                current = 'X';
                startingPlayer = 'X';
                gameOver = false;
                busy = false;
                status = vsComputer ? 'دورك يا بطل!' : 'دور اللاعب الأول';
              });
              _tone(650);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: pink,
              side: BorderSide(color: pink.withOpacity(0.6)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NeonBackground extends StatelessWidget {
  const _NeonBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _glow(260, cyan.withOpacity(0.07)),
          ),
          Positioned(
            bottom: -110,
            left: -100,
            child: _glow(290, purple.withOpacity(0.09)),
          ),
          Positioned(
            top: 300,
            right: -170,
            child: _glow(260, pink.withOpacity(0.045)),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 100, spreadRadius: 25),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cyan.withOpacity(0.035)
      ..strokeWidth = 0.6;

    const spacing = 28.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
