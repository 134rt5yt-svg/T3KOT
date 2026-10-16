# T3KOT

> **My first game!** Built from scratch with Godot 4 while learning
> game development: from jump and wall-jump physics to fog, a cutscene, and UI.

A first-person 3D platformer: climb up giant platforms through the fog.

![Godot 4](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-355570?logo=godotengine&logoColor=white)
![License](https://img.shields.io/badge/status-first_game-8A2BE2)

## Features

- **Zigzag parkour** — platforms alternate left/right, so you jump diagonally.
- **Wall-jump with slow motion** — touch a wall mid-air and time slows down
  (time scale 0.3); press jump again in time to kick off the wall.
- **Living camera** — 5 animation layers: walk bobbing, breathing while idle,
  a springy dip on landing, body roll when strafing, and FOV widening
  during fast falls.
- **Atmosphere** — thick fog, a sun with limited shadow distance, platforms
  hanging on textured chains that fade into the haze.
- **Finale** — a white flash, subtitles, and "THE END" on the highest platform.
- **Checkpoints** — fall down → respawn on the last platform you stood on.

# Running the game

## From source
1. Open Godot → **Import** → select the project folder (`project.godot`).
2. Press **F5** (Run Project).

## Install from releases
1. Go to the project's Releases page.
2. Download the file for your computer.
3. Run the game.

## What I learned (first project)

- character physics with `CharacterBody3D`: acceleration, gravity, jumps;
- raycasts and wall-jumping with `Engine.time_scale`;
- procedural camera animation using sines and springs;
- environment: `WorldEnvironment` (fog), lighting, shadow distance;
- optimization: scene instances, `visibility_range`, disabling shadows on small details;
- UI: subtitles, screen flash, a pixel font.

## Music

None yet.

---
*Open to advice and feedback — I'm just learning!*
