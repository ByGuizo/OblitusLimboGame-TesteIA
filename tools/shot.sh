#!/usr/bin/env bash
# Uso: tools/shot.sh <nome> <frames> <fps> <cena> -- <args do jogo>
# Renderiza quadros com o movie maker do Godot em frames/<nome>/ e imprime erros.
cd "$(dirname "$0")/.."
name="$1"; shift; n="$1"; shift; fps="$1"; shift; scene="$1"; shift
rm -rf "frames/$name"; mkdir -p "frames/$name"
timeout 1200 ./engine/Godot_v4.7.2-stable_win64_console.exe --path OblitusLimbo --write-movie "$(pwd -W)/frames/$name/f.png" --fixed-fps "$fps" --quit-after "$n" "$scene" "$@" 2>&1 | grep -E "ERROR|SCRIPT|Parse|error|Warning|WARNING" | grep -v "RID allocations\|Leaked\|leaked\|ObjectDB\|resources still in use\|Pages in use\|instance_notify" | head -30
ls "frames/$name" | grep png | wc -l
