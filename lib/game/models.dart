import 'dart:convert';

enum PieceType { circle, diamond, square, triangle, cross }

enum MatchMode { local, computer, online }

enum AiDifficulty { easy, normal, hard }

enum BoardThemeId { neon, wood, obsidian, prism }

extension PieceTypeName on PieceType {
  String get wireName => name;

  String get displayName => switch (this) {
    PieceType.circle => 'Circle',
    PieceType.diamond => 'Diamond',
    PieceType.square => 'Square',
    PieceType.triangle => 'Triangle',
    PieceType.cross => 'Cross',
  };

  int get pointValue => switch (this) {
    PieceType.circle => 1,
    PieceType.triangle => 3,
    PieceType.square => 5,
    PieceType.diamond => 6,
    PieceType.cross => 0,
  };

  int get aiValue => switch (this) {
    PieceType.circle => 100,
    PieceType.triangle => 325,
    PieceType.square => 455,
    PieceType.diamond => 525,
    PieceType.cross => 25000,
  };

  static PieceType fromWire(Object? value) {
    final text = value?.toString();
    return PieceType.values.firstWhere(
      (candidate) => candidate.name == text,
      orElse: () => throw FormatException('Unknown piece type: $value'),
    );
  }
}

class Piece {
  const Piece({
    required this.id,
    required this.type,
    required this.player,
    required this.row,
    required this.col,
    this.facing = 0,
    this.alive = true,
  });

  final String id;
  final PieceType type;
  final int player;
  final int row;
  final int col;
  final int facing;
  final bool alive;

  Piece copyWith({
    String? id,
    PieceType? type,
    int? player,
    int? row,
    int? col,
    int? facing,
    bool? alive,
  }) {
    return Piece(
      id: id ?? this.id,
      type: type ?? this.type,
      player: player ?? this.player,
      row: row ?? this.row,
      col: col ?? this.col,
      facing: facing ?? this.facing,
      alive: alive ?? this.alive,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.wireName,
    'player': player,
    'r': row,
    'c': col,
    'facing': facing,
    'alive': alive,
  };

  factory Piece.fromJson(Map<Object?, Object?> json) {
    return Piece(
      id: json['id']?.toString() ?? '',
      type: PieceTypeName.fromWire(json['type']),
      player: _asInt(json['player'], fallback: 1),
      row: _asInt(json['r']),
      col: _asInt(json['c']),
      facing: _asInt(json['facing']),
      alive: json['alive'] != false,
    );
  }
}

class GameMove {
  const GameMove({
    required this.pieceId,
    required this.player,
    required this.type,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.captures = const <String>[],
    this.newFacing = 0,
    this.landingRow,
    this.landingCol,
    this.distance = 0,
    this.turn = 0,
    this.preTurn = 0,
    this.travelFacing = 0,
    this.jumped = false,
    this.diamondCapture = false,
    this.edgeBlast = false,
    this.destroyTargetId,
    this.selfDestruct = false,
    this.arrivalKey,
    this.edgeFallback = false,
  });

  final String pieceId;
  final int player;
  final PieceType type;
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final List<String> captures;
  final int newFacing;
  final int? landingRow;
  final int? landingCol;
  final int distance;
  final int turn;
  final int preTurn;
  final int travelFacing;
  final bool jumped;
  final bool diamondCapture;
  final bool edgeBlast;
  final String? destroyTargetId;
  final bool selfDestruct;
  final String? arrivalKey;
  final bool edgeFallback;

  int get resolvedLandingRow => landingRow ?? toRow;
  int get resolvedLandingCol => landingCol ?? toCol;
  bool get isCapture => captures.isNotEmpty;

  String get signature => <Object?>[
    pieceId,
    toRow,
    toCol,
    resolvedLandingRow,
    resolvedLandingCol,
    newFacing,
    captures.join(','),
    selfDestruct ? 1 : 0,
    destroyTargetId ?? '',
    jumped ? 1 : 0,
    turn,
    preTurn,
  ].join('|');

  GameMove copyWith({
    List<String>? captures,
    int? toRow,
    int? toCol,
    int? newFacing,
    bool? edgeBlast,
    String? destroyTargetId,
    bool? selfDestruct,
    String? arrivalKey,
    bool? edgeFallback,
  }) {
    return GameMove(
      pieceId: pieceId,
      player: player,
      type: type,
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: toRow ?? this.toRow,
      toCol: toCol ?? this.toCol,
      captures: captures ?? this.captures,
      newFacing: newFacing ?? this.newFacing,
      landingRow: landingRow,
      landingCol: landingCol,
      distance: distance,
      turn: turn,
      preTurn: preTurn,
      travelFacing: travelFacing,
      jumped: jumped,
      diamondCapture: diamondCapture,
      edgeBlast: edgeBlast ?? this.edgeBlast,
      destroyTargetId: destroyTargetId ?? this.destroyTargetId,
      selfDestruct: selfDestruct ?? this.selfDestruct,
      arrivalKey: arrivalKey ?? this.arrivalKey,
      edgeFallback: edgeFallback ?? this.edgeFallback,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'pieceId': pieceId,
    'player': player,
    'type': type.wireName,
    'fromR': fromRow,
    'fromC': fromCol,
    'toR': toRow,
    'toC': toCol,
    'captures': captures,
    'newFacing': newFacing,
    'landingR': resolvedLandingRow,
    'landingC': resolvedLandingCol,
    'distance': distance,
    'turn': turn,
    'preTurn': preTurn,
    'travelFacing': travelFacing,
    'jumped': jumped,
    'diamondCapture': diamondCapture,
    'edgeBlast': edgeBlast,
    'destroyTargetId': destroyTargetId,
    'selfDestruct': selfDestruct,
    'arrivalKey': arrivalKey,
    'edgeFallback': edgeFallback,
  };

  factory GameMove.fromJson(Map<Object?, Object?> json) {
    return GameMove(
      pieceId: json['pieceId']?.toString() ?? '',
      player: _asInt(json['player'], fallback: 1),
      type: PieceTypeName.fromWire(json['type']),
      fromRow: _asInt(json['fromR']),
      fromCol: _asInt(json['fromC']),
      toRow: _asInt(json['toR']),
      toCol: _asInt(json['toC']),
      captures: _asStringList(json['captures']),
      newFacing: _asInt(json['newFacing']),
      landingRow: json['landingR'] == null ? null : _asInt(json['landingR']),
      landingCol: json['landingC'] == null ? null : _asInt(json['landingC']),
      distance: _asInt(json['distance']),
      turn: _asInt(json['turn']),
      preTurn: _asInt(json['preTurn']),
      travelFacing: _asInt(json['travelFacing']),
      jumped: json['jumped'] == true,
      diamondCapture: json['diamondCapture'] == true,
      edgeBlast: json['edgeBlast'] == true,
      destroyTargetId: json['destroyTargetId']?.toString(),
      selfDestruct: json['selfDestruct'] == true,
      arrivalKey: json['arrivalKey']?.toString(),
      edgeFallback: json['edgeFallback'] == true,
    );
  }
}

class LastMoveSummary {
  const LastMoveSummary({
    required this.move,
    required this.mover,
    required this.pointsGained,
  });

  final GameMove move;
  final int mover;
  final int pointsGained;

  Map<String, Object?> toJson() => <String, Object?>{
    ...move.toJson(),
    'mover': mover,
    'pointsGained': pointsGained,
    'selfDestructId': move.selfDestruct ? move.pieceId : null,
  };

  factory LastMoveSummary.fromJson(Map<Object?, Object?> json) {
    return LastMoveSummary(
      move: GameMove.fromJson(json),
      mover: _asInt(
        json['mover'],
        fallback: _asInt(json['player'], fallback: 1),
      ),
      pointsGained: _asInt(json['pointsGained']),
    );
  }
}

class GameResult {
  const GameResult({
    required this.type,
    required this.winner,
    required this.reason,
  });

  final String type;
  final int winner;
  final String reason;

  bool get isDraw => type == 'draw';

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'winner': winner,
    'reason': reason,
  };

  factory GameResult.fromJson(Map<Object?, Object?> json) {
    return GameResult(
      type: json['type']?.toString() ?? 'draw',
      winner: _asInt(json['winner']),
      reason: json['reason']?.toString() ?? '',
    );
  }
}

class GameState {
  const GameState({
    this.boardSize = 9,
    required this.pieces,
    required this.currentPlayer,
    required this.halfmoveClock,
    required this.positionCounts,
    required this.gameOver,
    required this.result,
    required this.scores,
    required this.lastMove,
    required this.moveNumber,
  });

  final int boardSize;
  final List<Piece> pieces;
  final int currentPlayer;
  final int halfmoveClock;
  final Map<String, int> positionCounts;
  final bool gameOver;
  final GameResult? result;
  final Map<int, int> scores;
  final LastMoveSummary? lastMove;
  final int moveNumber;

  GameState copyWith({
    List<Piece>? pieces,
    int? currentPlayer,
    int? halfmoveClock,
    Map<String, int>? positionCounts,
    bool? gameOver,
    GameResult? result,
    bool clearResult = false,
    Map<int, int>? scores,
    LastMoveSummary? lastMove,
    bool clearLastMove = false,
    int? moveNumber,
  }) {
    return GameState(
      boardSize: boardSize,
      pieces: pieces ?? this.pieces,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      halfmoveClock: halfmoveClock ?? this.halfmoveClock,
      positionCounts: positionCounts ?? this.positionCounts,
      gameOver: gameOver ?? this.gameOver,
      result: clearResult ? null : (result ?? this.result),
      scores: scores ?? this.scores,
      lastMove: clearLastMove ? null : (lastMove ?? this.lastMove),
      moveNumber: moveNumber ?? this.moveNumber,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'boardSize': boardSize,
    'pieces': pieces.map((piece) => piece.toJson()).toList(growable: false),
    'currentPlayer': currentPlayer,
    'halfmoveClock': halfmoveClock,
    'positionCounts': positionCounts,
    'gameOver': gameOver,
    'result': result?.toJson(),
    'scores': <String, int>{'1': scores[1] ?? 0, '2': scores[2] ?? 0},
    'lastMove': lastMove?.toJson(),
    'moveNumber': moveNumber,
  };

  factory GameState.fromJson(Map<Object?, Object?> json) {
    final piecesValue = json['pieces'];
    final rawPieces = piecesValue is List ? piecesValue : const <Object?>[];
    final scoreMap = _asMap(json['scores']);
    final positionMap = _asMap(json['positionCounts']);
    final rawResult = _asMapOrNull(json['result']);
    final rawLastMove = _asMapOrNull(json['lastMove']);

    return GameState(
      boardSize: _asInt(json['boardSize'], fallback: 9) == 7 ? 7 : 9,
      pieces: rawPieces
          .whereType<Map<Object?, Object?>>()
          .map(Piece.fromJson)
          .toList(growable: false),
      currentPlayer: _asInt(json['currentPlayer'], fallback: 1),
      halfmoveClock: _asInt(json['halfmoveClock']),
      positionCounts: <String, int>{
        for (final entry in positionMap.entries)
          entry.key.toString(): _asInt(entry.value),
      },
      gameOver: json['gameOver'] == true,
      result: rawResult == null ? null : GameResult.fromJson(rawResult),
      scores: <int, int>{
        1: _asInt(scoreMap[1] ?? scoreMap['1']),
        2: _asInt(scoreMap[2] ?? scoreMap['2']),
      },
      lastMove: rawLastMove == null
          ? null
          : LastMoveSummary.fromJson(rawLastMove),
      moveNumber: _asInt(json['moveNumber']),
    );
  }

  String encode() => jsonEncode(toJson());

  factory GameState.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Game state is not an object');
    }
    return GameState.fromJson(Map<Object?, Object?>.from(decoded));
  }
}

class MatchSnapshot {
  const MatchSnapshot({required this.state, required this.description});

  final GameState state;
  final String description;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<Object?, Object?> _asMap(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return Map<Object?, Object?>.from(value);
  return const <Object?, Object?>{};
}

Map<Object?, Object?>? _asMapOrNull(Object? value) {
  if (value == null) return null;
  return _asMap(value);
}
