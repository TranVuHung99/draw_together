Project Overview

Build a real-time collaborative drawing mini-game inspired by r/place, but instead of placing pixels, each player is assigned a dedicated rectangular region where they can freely draw.

Tech Stack

Frontend: Flutter (Web-first, Mobile supported)

Backend: Serverpod (latest stable version)

Database: PostgreSQL (via Serverpod)

Realtime communication: Serverpod streaming / WebSocket

State management (Flutter): Riverpod

Do not use Firebase.

Focus only on core features.

🎮 Core Game Concept

A shared global canvas exists inside a room.

A player can create a room and becomes the Game Master (Host).

Other players join using a room code.

When the host starts the game:

The canvas is partitioned automatically into rectangular regions.

Each player is assigned exactly one region.

Players can draw freely inside their own region only.

All drawing is synchronized in real-time.

The host can observe all regions being drawn live.

After a fixed time limit:

Drawing stops.

All regions are merged into one final composite image.

The final image is displayed to all players.

🧩 Core Requirements
Room System

Create room

Join room by code

Host controls start game

Basic game state:

WAITING

PLAYING

FINISHED

Canvas Partition

Global canvas has configurable width and height.

When the game starts:

Automatically calculate a grid layout based on player count.

Assign each player a unique rectangular region.

Regions should be evenly distributed and deterministic.

Drawing System (Paint-like)

Implement a freehand drawing tool with:

Freehand strokes

Color selection

Stroke width selection

Eraser tool

Undo (only own strokes)

Each stroke must contain:

id

playerId

list of points

color

strokeWidth

isEraser

timestamp

Players must only be able to draw inside their assigned region.

Realtime Behavior

All strokes are synchronized in real time.

Do not resend entire canvas on every update.

Send incremental stroke updates.

Host can see everything live.

All players see merged canvas in real time.

Game End

When timer ends:

Lock drawing.

Merge all strokes into a single final image.

Display the final composite canvas to all players.

The merge strategy (client-side or server-side) can be decided by the AI Agent.

🧠 AI Agent Instructions

Act as a senior full-stack engineer.

Design and implement:

Backend models (Serverpod latest)

Endpoints

Realtime communication

Canvas partition logic

Flutter drawing engine

State management structure

You are free to decide architecture details, but focus only on delivering the core playable version of the game.

Do not include advanced features, scaling optimizations, deployment setup, or extra extensions.