# Daven Did It

A 2D Godot game where you play as Daven the heart.

## Current structure

```text
res://
├─ project.godot
├─ icon.svg
├─ scenes/
│  └─ main.tscn              # entry point (registered as main scene)
├─ scripts/
│  └─ main.gd
├─ assets/
│  ├─ sprites/
│  │  └─ CuteHeartDaven.png  # Daven, the player character
│  ├─ audio/
│  ├─ fonts/
│  └─ shaders/
└─ ui/                       # title, win, lose, HUD
```

## Planned structure

```text
res://
├─ main.tscn / main.gd        # loads zones in order
├─ autoload/
│  └─ game_manager.gd         # lives, zone list
├─ zones/
│  ├─ zone.gd                 # base script every zone extends
│  ├─ zone1_platformer/
│  ├─ zone2_gravity/          # tanish
│  └─ zone3_daven_boss/       # tanish
└─ shared/
   ├─ bounce_pad/             # shared scene everyone reuses
   └─ ui/                     # title, win, lose, HUD
```
