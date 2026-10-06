# Twelve · Sprite Animation Lab

A mobile-first teaching app for **Unit A1 · Skills Development** on Level 3
Games Development. It teaches the twelve principles of animation through the one
job every games student has to get right early: a sprite walk cycle that reads
well, loops cleanly and doesn't skate across the floor once it is in Unreal.

**Live site:** https://jamesbell2021.github.io/Animation-/animation-principles/
(once GitHub Pages is switched on for this repo)

## The idea

Most animation-principles resources stop at the bouncing ball. This one carries
the principles all the way into the engine. Everything in the app is budgeted
against **the 8-frame rule**: a readable walk needs four keys and four
breakdowns, nothing more. Students learn each principle and practise it on a
walk. Then they build that walk in After Effects, bring it into Unreal as a
Paper2D flipbook, and work out the movement speed so the feet grip the ground.

## Sections

| Section | What it does |
|---|---|
| All 12 Principles | Squash & stretch through to appeal. Each principle is shown in motion, explained in game terms, with a "don't" and a link to practise it. Progress counts how many principles have landed. |
| Walk Lab | An 8-frame walk with onion skinning and a tappable timeline. It compares tweened and drawn timing using the same eight keys, so students can see why After Effects' default interpolation looks floaty and Posterize Time doesn't. |
| AE → Unreal Pipeline | A step-by-step checklist from comp setup, rig building, pose-to-pose animation and rendering in After Effects, through to texture import, flipbook creation and hooking it up to the character in Unreal. |
| Timing Maths | A foot-slide solver. It uses cycle time, travel per frame and sprite scale to work out the Max Walk Speed to type into Unreal, with a side-by-side showing matched feet vs. skating feet. |
| Glossary | Searchable terms for poses, timing, method and engine, including key, breakdown, in-between and more. Students are expected to use these words in their commentary and crit. |
| Critique | A broken, tweened walk with six faults to spot. It trains the eye before students critique their own work. |
| Where This Came From | A timeline from the thaumatrope (1825) to *Prince of Persia* (1989), plus a persistence-of-vision demo. It ends with a research task that evidences A1.1. |
| Unit A1 Evidence | Maps a single walk cycle to all five objectives, A1.1 to A1.5, with plain-English Pass, Merit and Distinction guidance and an evidence pack checklist. |

## Why a walk cycle

A walk cycle can evidence all five Unit A1 objectives, but only if students keep
the research, the versions and the critique, not just the finished loop. The app
is built to make that process visible. The Unit A1 guidance is written in plain
English and is not the official wording, so check it against the specification
and the assignment brief.

## Technical notes

- A single self-contained `index.html` with no build step, no dependencies and
  nothing else to upload.
- Works on phones, tablets and laptops, and can be added to a phone home screen
  (Share → Add to Home Screen).
- Every animation is drawn in code. There is no third-party art, so it is safe
  to publish publicly.

## Updating

Re-export `index.html` and replace the one in this folder. GitHub Pages
republishes automatically.

---

James Bell · Belfast Metropolitan College · Games Development
