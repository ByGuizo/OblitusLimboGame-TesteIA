#!/usr/bin/env bash
# Verifica a sintaxe de todos os scripts GDScript do projeto
cd "$(dirname "$0")/.."
for f in $(cd OblitusLimbo && find scripts -name "*.gd"); do
  out=$(./engine/Godot_v4.7.2-stable_win64_console.exe --headless --path OblitusLimbo --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" | grep -v "Failed to compile depended" )
  if [ -n "$out" ]; then echo "== $f"; echo "$out" | head -8; fi
done
echo "check done"
