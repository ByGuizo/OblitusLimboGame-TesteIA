#!/usr/bin/env bash
# Verifica se todos os kits de personagem compilam e instanciam.
cd "$(dirname "$0")/.."
timeout 120 ./engine/Godot_v4.7.2-stable_win64_console.exe --headless --path OblitusLimbo res://scenes/main.tscn -- --checkkits 2>&1 | grep -E "KIT|SCRIPT ERROR|Parse" | head -40
