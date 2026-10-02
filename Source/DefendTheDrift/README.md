# Defend the Drift: C++ source

The C++ systems for the build guide "Defend the Drift: Design & Build Guide". These
are the files the guide's Phase 1 calls "the zip".

## Using it (build guide, Phase 1)

1. Create a UE 5.8 C++ Blank project named exactly `DefendTheDrift` (the code uses
   `DEFENDTHEDRIFT_API`), and add the Third Person content pack.
2. Close the editor and copy every file in this folder into the project's
   `Source/DefendTheDrift/`, overwriting `DefendTheDrift.Build.cs`. Keep the
   `DefendTheDrift.h/.cpp` and `*.Target.cs` files Unreal made.
3. Build the editor target and reopen the project.

## Classes

| File | Class | Job |
| --- | --- | --- |
| `DTDTypes.h` | enums | Faction, Formation, Unit State |
| `DTDUnit` | `ADTDUnit` | One man: stance, volley, fire arc, reload, targeting, melee, death |
| `DTDSquadComponent` | `UDTDSquadComponent` | Spawns units, formation slots, passes orders on, `On Order Given` event |
| `DTDCommander` | `ADTDCommander` | One per squad; the pawn a player drives; carries the squad |
| `DTDSquadStart` | `ADTDSquadStart` | Where and when a squad enters |
| `DTDPlayerController` | `ADTDPlayerController` | Enhanced Input to squad orders, switching squads, camera-relative movement |
| `DTDGameMode` | `ADTDGameMode` | Creates Player 2, sides, squad arrivals, reserves, win check |
| `DTDGameState` | `ADTDGameState` | Time left, clock, capture progress, counts, winner |
| `DTDSharedCamera` | `ADTDSharedCamera` | One couch camera framing the two commanders being driven |
| `DTDObjectiveZone` | `ADTDObjectiveZone` | Box over the storehouse; counts who is inside |

## How it fits together

- Players never possess a pawn. Each `ADTDPlayerController` drives one
  `ADTDCommander` of its side by calling `AddMovementInput` on it, and its view
  stays on the `ADTDSharedCamera`. Q / LB moves to the next arrived squad.
- Commanders and units run with no controller (`bRunPhysicsWithNoController`).
  The squad component works out slots around its commander every frame and each
  unit walks to its slot and faces the slot's direction.
- Line of sight is a chest-to-chest trace against `WorldStatic` only. Standing
  chest height is about 141 cm and kneeling about 64 cm, so a 110 cm wall hides a
  kneeling man but not a standing one.
- Commanders are not units, so nothing targets them; they cannot fall.

## Blueprint hooks

- `ADTDUnit`: `On Fired (Target, bHit)`, `On Reload Started`, `On Melee Attack`, `On Died`.
- `UDTDSquadComponent`: `On Order Given (Name)` with `Volley`, `Charge`,
  `GroundOn`, `GroundOff` or `Formation`.
- `ADTDGameMode`: `On Match Ended (Winner, Reason)`.
- `ADTDGameState`: `Get Clock Text`, `Get Night Progress`, `Capture Progress`,
  `British Standing`, `Zulu On Field`, `Zulu To Come`, `Get Faction Name`.

Units ragdoll on death by default (`Ragdoll On Death`); turn it off once `On Died`
plays a fall montage.
