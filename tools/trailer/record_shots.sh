#!/usr/bin/env bash
# Graba los planos del tráiler como secuencias PNG de 320x180 a 30 fps en builds/trailer/raw/<plano>/.
# Uso: bash tools/trailer/record_shots.sh [plano...]   (sin argumentos graba todos)
set -u
cd "$(dirname "$0")/../.."
G="${GODOT:-/d/Progamas de Windows/Godot/Godot_v4.7.2-stable_win64.exe}"
MAP="--map=res://maps/hospital.txt"

declare -A ARGS=(
  [walk]="$MAP --trailer=walk --nohud --frames=300"
  [approach]="$MAP --trailer=approach --nohud --frames=330"
  [gens]="$MAP --trailer=gens --nohud --frames=270"
  [coop]="$MAP --trailer=coop --nohud --frames=360"
  [dart]="$MAP --trailer=dart --nohud --frames=330"
  [scream]="$MAP --trailer=scream --frames=300"
  [revive]="--scenario=revive --nomonster --frames=300"
  [door]="$MAP --trailer=door --nohud --frames=360"
  [future_stalker]="$MAP --trailer=future_stalker --nohud --frames=300"
  [future_girl]="$MAP --trailer=future_girl --nohud --frames=300"
  [future_corpse]="$MAP --trailer=future_corpse --nohud --frames=300"
)

shots=("$@")
[ ${#shots[@]} -eq 0 ] && shots=(walk approach gens coop dart scream revive door future_stalker future_girl future_corpse)
for s in "${shots[@]}"; do
  rm -rf "builds/trailer/raw/$s" && mkdir -p "builds/trailer/raw/$s"
  # shellcheck disable=SC2086
  timeout 180 "$G" --path . --write-movie "builds/trailer/raw/$s/f.png" --fixed-fps 30 \
    res://scenes/main.tscn -- ${ARGS[$s]} 2>&1 | grep -E "SCRIPT ERROR" | head -3
  echo "$s: $(ls "builds/trailer/raw/$s" | grep -c png) fotogramas"
done
