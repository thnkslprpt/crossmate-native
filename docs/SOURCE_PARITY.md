# Browser source parity

## Baseline

This rewrite follows the rules and product behavior in the current browser release, Crossmate v1.8.1, from `games/crossmate/index.html` in the Gidi Games repository.

The Dart engine is an independent implementation. It does not execute, embed, or translate the browser JavaScript at runtime.

## Preserved game rules

- Choice of 7×7 (14 pieces per player) or 9×9 (16 pieces per player), preserved in online state and rematches
- Random opening player for local and online games
- Human remains Player 1 in robot games, including when the robot opens
- Circle vertical movement, forward-diagonal capture, and far-edge sacrifice
- Triangle actions are separate: turn to any other cardinal direction, move one empty square forward, or capture ahead, diagonally ahead, or two squares ahead through an empty square
- Triangles may capture diamonds while ignoring only the target diamond’s own field
- Square-backed triangle piece housing, matching the v1.8.1 browser design
- Square straight movement, one non-capturing jump, optional later ordinary capture, and direct diamond landing
- Diamond one-square movement and an eight-cell forcefield whose new area may contain no enemy piece
- Cross one-to-three-square movement in eight directions and stop after first capture
- A player's own forcefield is transparent when checking attacks against that player's cross
- Own cross may enter its own forcefield and remains vulnerable to check there
- Check, legal-response filtering, cross capture, and Crossmate: no legal moves is a loss even without check, taking priority over draws
- Draw after three repeated full positions
- Draw after 60 consecutive player moves without a capture
- Draw when only the two crosses remain
- Current capture values: Circle 1, Triangle 3, Square 5, Diamond 6
- Three robot difficulty levels
- Move-history review and the four current board themes
- Ten-day online room expiry

## Deliberate first-beta differences

- Native rooms use `crossmateNativeRooms`, so browser and native players cannot yet join the same room.
- Room sharing sends a room code and instructions rather than a universal/app link.
- The current match is not restored after the local app process is terminated.
- Expired Firebase rooms are rejected by clients but are not automatically deleted.
- There is no push notification, Game Center, Play Games, achievement, sound, or haptic layer yet.
- The native interface is a new Flutter design rather than a pixel-for-pixel copy of the browser page.

## Release gate

Before a public store submission, compare the native engine against recorded browser positions for every piece type, special capture, forcefield edge case, game-ending condition, and robot opening choice. Also complete two-device Firebase testing under reconnect, background/resume, and stale-room conditions.
