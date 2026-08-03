# Architecture

## Design goal

Crossmate Native uses one Flutter/Dart codebase for Android and iOS while remaining a true compiled app. No game page is embedded and no web runtime is required for local play.

## Main layers

```text
lib/
├── game/
│   ├── models.dart       immutable state and wire models
│   ├── engine.dart       legal moves, checks, scoring and endings
│   ├── ai.dart           isolate-based minimax AI
│   ├── controller.dart   match/session orchestration
│   └── palette.dart      visual themes
├── services/
│   ├── online_service.dart
│   └── settings_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── game_screen.dart
│   ├── rules_screen.dart
│   └── theme_screen.dart
└── widgets/
    ├── app_background.dart
    └── crossmate_board.dart
```

## State model

`GameState` is immutable and JSON serializable. A move is accepted only after the engine reconstructs the matching canonical legal move. This same validation path is used by local games, the robot, and Firebase transactions.

## AI

The AI receives a serialized state through Flutter `compute`, so search does not block touch animation on the UI isolate. Easy uses noisy tactical ranking. Normal uses two-ply alpha-beta. Hard uses iterative search up to four plies with a time budget.

## Online play

Online rooms use Firebase Anonymous Authentication and Realtime Database transactions. The shipped client reconstructs the canonical legal move, confirms that it is the player's turn, and writes the complete next immutable state atomically. Firebase rules restrict writes to room members and keep room identity metadata immutable. Because game legality is still evaluated on the client, this beta is not cheat-proof against a deliberately modified app; competitive play would need a server-authoritative move validator.

The native room root is separate from the browser game:

```text
crossmateNativeRooms/{ROOM_CODE}
```

This avoids schema conflicts during the rewrite. Cross-platform web/native rooms can be added later with an explicit versioned migration.

## Platform projects

`scripts/bootstrap.sh` generates Android on Ubuntu and any missing Android/iOS hosts on macOS. Keeping generation scripted makes the source package smaller and prevents stale generated files from becoming the source of truth. Once a production release is near, it is reasonable to commit the generated platform folders so native signing and capabilities changes are reviewed in Git.
