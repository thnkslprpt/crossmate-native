# Firebase setup

## Products used

- Authentication: Anonymous sign-in
- Realtime Database: private room state and presence

No Cloud Functions are required for the current beta.

## Automated setup

After `./scripts/bootstrap.sh`:

```bash
./scripts/configure_firebase.sh YOUR_FIREBASE_PROJECT_ID
```

Then enable Anonymous authentication in Firebase Console.

## Rules

The supplied rules are in:

```text
firebase/database.rules.json
```

They allow authenticated users to read a room code, create a room as Player 1, claim an empty Player 2 slot, and write only when they are one of the room members. Room identity metadata and occupied player slots are immutable. Presence entries can only be written by the matching authenticated user.

The rules do not independently prove that a board transition is a legal Crossmate move. The shipped app validates every move in a transaction, but a hostile modified client could attempt to cheat. A competitive public mode should move canonical validation to a trusted server or Cloud Function.

Before public launch, use the Firebase emulator suite to add adversarial rule tests, rate-limit room creation through App Check or a server component if abuse appears, and add scheduled cleanup for expired rooms.

## App Check

App Check is not enabled in this first package because Android Play Integrity and Apple App Attest/DeviceCheck need release signing and store configuration. Add it before or shortly after public launch if online play is exposed broadly.

## Room lifetime

Rooms have an `expiresAt` value ten days after creation. The client refuses expired rooms. Expired data is not automatically deleted in this beta; a scheduled backend cleanup can remove it later.
