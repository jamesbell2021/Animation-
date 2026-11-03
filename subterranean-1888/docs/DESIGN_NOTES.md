# Design notes: from the GDD to a playable rule set

The *Subterranean: 1888* GDD has a strong theme and good systemic hooks, but some rules were missing, contradictory, or broke once numbers went in. This file lists each gap and the decision the prototype makes. Every value lives in `rules/rules.gd` or the `.tres` files in `data/`, so any of them can be changed in one place.

## Time Units

| GDD | Problem | Prototype |
|---|---|---|
| Max TU comes from "Agility and Equipment Loadout Weight", but each class has a fixed Max TU and no Agility | Contradiction | The class value is the **base**. Every kg (rounded up) carried over **Strength ÷ 4** costs 1 TU. Strength now matters. The Grenadier carries 26 kg against a 23.75 kg allowance, so he has 42 TU; the Cartographer has 58; the others are under their limits. |
| The code charged 6 TU for a crouched step; the table didn't mention crouched movement | Missing rule | +2 TU a step while crouched |
| Shots cost a share of Max TU | Fine, but a high-TU unit gets no extra shots, only extra movement | Kept, as in X-COM. Melee weapons (drill, mandibles, claws) cost a flat amount instead |
| Turning costs 1 TU per 45° | Walking could have been a free way to turn | Walking turns you for free, but walking one step and back always costs more than rotating, so there's no exploit |

## Overwatch and reaction fire

The GDD's formula was `Remaining TU × Perception > Enemy Agility`. An Engineer holding 17 TU scores 935 against an agility under 100, so overwatch always fired first.

**Prototype:** both sides use the same scale.

```
reactor score = Perception × (TU left / Max TU)
mover score   = Agility    × (TU left / Max TU)
```

The check runs **after every step** the mover takes inside the watcher's cone, and the higher score acts first. Movers spend TU as they walk, so the deeper a creature comes into a watched cone, the likelier the shot. A reaction shot spends the watcher's TU, so each later reaction is less likely. The combat log prints both scores, which makes the system visible to players and to students.

A unit goes on Overwatch automatically if it ends its turn with at least a third of its Max TU (GDD 2.3). Insects with TU left also "react" with a bite when a soldier steps beside them.

## Light

| GDD | Problem | Prototype |
|---|---|---|
| Bands 0–0.2, 0.3–0.7, 0.8–1.0 | 0.2–0.3 and 0.7–0.8 belonged to no band | Half-open bands: pitch below 0.25, dim below 0.75, bright from 0.75 up |
| Default tile light of 0.1 | The whole map is pitch black | Kept, deliberately. Light is the resource. Sources are: fungus grottos, each specialist's Davy lamp (lights 2 tiles round, but the swarm sees you; **L** shutters it), workers' glowing abdomens, hand flares and mortar flares |
| Flare radius 7 | On a 30×30 map one flare lit a sixth of it | Hand flare radius 3, mortar flare radius 4, both burning out over 3 turns |
| "Cannot target beyond 2 tiles in pitch black" | Kept | The HUD says why a shot can't be taken |
| Steam blocks line of sight | Kept | Steam blocks sight but not light. A valve shuts the vents near it |

Sight: a 90° cone out to 12 tiles, plus anything within 2 tiles (hearing), both needing line of sight. To make out a creature you also need its tile to be lit, or to be within 2 tiles. That is why a worker's glow gives it away while a crawler can stand in the dark.

## Accuracy, damage, cover (missing from the GDD)

```
hit % = weapon accuracy
      + mode (snap -15, aimed +30, burst -10 a round)
      + 10 if the shooter is crouched
      - 4 for each tile past the weapon's optimal range
      + light at the target (pitch -50, dim 0, bright +10)
      - 20 if the target has cover on the shooter's side
      - 10 if the target is crouched
      (melee instead: +15 for striking from outside the target's cone)
clamped to 5..95
damage = weapon damage ± 25%, minus armour (the Grenadier's shield adds 6 against blows from in front)
```

Weapon table (data/weapons):

| Weapon | Damage | Accuracy | Range | Clip | Weight | Notes |
|---|---|---|---|---|---|---|
| Pneumatic Steam-Drill | 30 | 85 | melee | none | 9 kg | 15 TU a strike; also bores soft rock |
| Poisoned Dart Rifle | 12 | 70 | 14 | 4 | 5 kg | poisons, 4 damage a turn for 3 turns |
| Hand-Crank Gatling | 14 | 50 | 9 | 30 | 16 kg | snap or burst only |
| Brass Carbine | 20 | 65 | 12 | 8 | 6 kg | |

## Suppression, steam pressure

- **Burst** (GDD: "pins enemy TU") pins whatever survives it. The target starts its next turn at half TU and can't reaction-fire until then.
- **Steam pressure** (named by the GDD's Field Repair but never defined): each boiler holds 100. Every round costs the weapon's pressure, and pressure regains 10 a turn. Below 30 there's a chance to jam (2% for every point under 30). Field Repair (15 TU) restores 100 and clears a jam. The result is a push-your-luck resource on the gatling and the drill.

## The swarm

| GDD | Problem | Prototype |
|---|---|---|
| A creature that sees the squad drops a pheromone node on its own tile | Kept | Strength 1.0, capped at 3 a tile |
| Horde aggro: everything within 15 tiles follows the densest trail | With no decay, one sighting pulls the whole map for the rest of the game | Pheromone decays ×0.6 each enemy turn and disappears below 0.15, so a single sighting lasts about four turns. "Density" is the pheromone summed within 2 tiles |
| Flanking crawlers | Kept | Crawlers score attack tiles: +100 outside the target's cone, +40 behind it. A strike from outside the cone gets +15 to hit |
| — | Nothing ever started the fight | Creatures start dormant. They wake if they see the squad, smell pheromone within 15 tiles, are hurt, or hear gunfire within 8 tiles (melee 4, dynamite 10) |
| — | The Naturalist's pheromone grenades and the AI's pheromone were separate ideas | They're the same system. A lure lays a 2.5-strength node, and the swarm follows it like any other trail |
| — | No pressure to keep moving | Once roused, the hive births a crawler every 4 enemy turns, 3 at most |

## Co-op turn structure

The GDD's network code cycled players 0→3 one at a time, but Milestone 3 asked for simultaneous planning. The prototype is single-player, commanding all four, as in GDD 6.1's solo mode. It's built for a **shared player phase**: the Battle is server-authoritative in shape (commands in, events out, validated by `can()`), so co-op means the host runs the Battle and each client sends commands for the units it owns. Whose turn it is becomes "is this unit mine" rather than a rotating player index.

## Known trade-offs

- **The AI is greedy within each turn.** It doesn't coordinate beyond following the same pheromone.
- **Enemy melee reactions can surprise players.** An awake creature with TU left bites a soldier who steps beside it. The log shows the reaction scores so the cause is clear.
- **Rotating in place never triggers reaction fire,** so a soldier can turn on the spot to scout. That's cheap (1 TU per 45°) and deliberate: facing is information, and paying for it is the point.
