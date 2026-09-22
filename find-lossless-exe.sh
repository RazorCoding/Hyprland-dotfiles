#!/usr/bin/env bash
# Find the exact exe FILE running for each Steam game (name + PID + full path).
# Usage:
#   ./find-lossless-exe.sh                   # list exact exe + PID + FILE + Steam name (MAIN first per game)
#   ./find-lossless-exe.sh Age               # filter by exe, path, or Steam name (case-insensitive)
#   ./find-lossless-exe.sh --full            # show PID + EXE + FILE + AppID + full command line
#   ./find-lossless-exe.sh --pid             # show PID only
#   ./find-lossless-exe.sh --names           # show unique exact exe names only
#   ./find-lossless-exe.sh --paths           # show unique exact exe FILE paths only
#   ./find-lossless-exe.sh --exact Age       # exact-name match, not substring

set -euo pipefail

filter=""
exact=0
show_full=0
pid_only=0
names_only=0
paths_only=0
for arg in "$@"; do
  case "$arg" in
    --full|-f) show_full=1 ;;
    --pid|-p) pid_only=1 ;;
    --names|-n) names_only=1 ;;
    --paths) paths_only=1 ;;
    --exact) exact=1 ;;
    --help|-h)
      sed -n '2,10p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) filter="$arg" ;;
  esac
done

SELF_PID=$$
SELF_PPIDs=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ' || echo "")
SCRIPT_BASENAME=$(basename "$0")

# --- Steam library lookup ---
STEAMAPPS_DIRS=()
for d in \
  "$HOME/.local/share/Steam/steamapps" \
  "$HOME/.steam/steam/steamapps" \
  "$HOME/.steam/root/steamapps"; do
  [[ -d "$d" ]] && STEAMAPPS_DIRS+=("$d")
done

declare -A APPID_TO_NAME=()
declare -A INSTALLDIR_TO_APPID=()

load_steam_library() {
  local dir acf appid name installdir
  for dir in "${STEAMAPPS_DIRS[@]}"; do
    for acf in "$dir"/appmanifest_*.acf; do
      [[ -f "$acf" ]] || continue
      appid=$(grep -E '"appid"' "$acf" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)
      name=$(grep -E '"name"' "$acf" 2>/dev/null | head -1 | sed -E 's/.*"name"[[:space:]]+"(.*)".*/\1/' || true)
      installdir=$(grep -E '"installdir"' "$acf" 2>/dev/null | head -1 | sed -E 's/.*"installdir"[[:space:]]+"(.*)".*/\1/' || true)
      [[ -n "${appid:-}" ]] || continue
      [[ -n "${APPID_TO_NAME[$appid]:-}" ]] || APPID_TO_NAME["$appid"]="${name:-$appid}"
      if [[ -n "${installdir:-}" && -z "${INSTALLDIR_TO_APPID[$installdir]:-}" ]]; then
        INSTALLDIR_TO_APPID["$installdir"]="$appid"
      fi
    done
  done
}
load_steam_library

steam_name_for_appid() {
  local appid="$1"
  if [[ -n "${APPID_TO_NAME[$appid]:-}" ]]; then
    printf '%s' "${APPID_TO_NAME[$appid]}"
    return
  fi
  # fallback: read manifest directly
  local dir acf
  for dir in "${STEAMAPPS_DIRS[@]}"; do
    acf="$dir/appmanifest_${appid}.acf"
    if [[ -f "$acf" ]]; then
      grep -E '"name"' "$acf" 2>/dev/null | head -1 | sed -E 's/.*"name"[[:space:]]+"(.*)".*/\1/' || true
      return
    fi
  done
}

# Wine/Windows system services that aren't the actual game.
is_noise_exe() {
  local n="${1,,}"
  n="${n%.exe}"
  case "$n" in
    services|winedevice|plugplay|rpcss|svchost|conhost|explorer|tabtip|\
xalia|wineserver|wineboot|sihost|ctfmon|crashhandler|crashpad_handler|\
bsSndrpt*|bsSndRpt*|bugSplat*|testwebclient|aoeurlhelper|aoeurlinstaller_steam|\
steam|steamwebhelper|steamservice|steamerrorreporter|\
gameoverlayui|gameoverlayrenderer|\
reaper|steam-launch-wrapper|pressure-vessel|pv-adverb|srt-bwrap|srt-logger|\
wine|wine64|wine-preloader|wine64-preloader|wineserver|protons|proton|\
python|python3|perl|sh|bash|dash|zsh|ps|pgrep|grep)
      return 0 ;;
  esac
  return 1
}

is_wrapper_basename() {
  local n="${1,,}"
  case "$n" in
    steam|steam.sh|steamwebhelper|reaper|steam-launch-wrapper|\
srt-bwrap|srt-logger|pv-adverb|pressure-vessel-adverb|\
steam-runtime-launcher-service|wineserver|wine|wine64|\
wine-preloader|wine64-preloader|proton|python|python3|perl|\
bash|sh|zsh|dash|ps|pgrep|grep|sleep|timeout|cat|tr|find-lossless-exe.sh)
      return 0 ;;
  esac
  return 1
}

# Extract AppID for a pid from environ, then cmdline, then installdir path.
get_appid() {
  local pid="$1" cmd="$2" appid envdump
  # 1) environ SteamAppId / SteamGameId (most reliable for Proton)
  envdump=$(cat "/proc/$pid/environ" 2>/dev/null | tr '\0' '\n' 2>/dev/null || true)
  if [[ -n "$envdump" ]]; then
    appid=$(grep -E '^SteamAppId=' <<<"$envdump" | head -1 | cut -d= -f2 || true)
    if [[ -n "${appid:-}" && "$appid" != "0" ]]; then
      printf '%s' "$appid"
      return
    fi
    appid=$(grep -E '^SteamGameId=' <<<"$envdump" | head -1 | cut -d= -f2 || true)
    if [[ -n "${appid:-}" && "$appid" != "0" ]]; then
      printf '%s' "$appid"
      return
    fi
  fi
  # 2) cmdline AppId=12345 / steam_app_12345
  appid=$(grep -oE 'AppId=[0-9]+' <<<"$cmd" | head -1 | grep -oE '[0-9]+' || true)
  if [[ -n "${appid:-}" && "$appid" != "0" ]]; then
    printf '%s' "$appid"
    return
  fi
  appid=$(grep -oiE 'steam_app_[0-9]+' <<<"$cmd" | head -1 | grep -oE '[0-9]+' || true)
  if [[ -n "${appid:-}" ]]; then
    printf '%s' "$appid"
    return
  fi
  # 3) installdir in path -> appid (e.g. steamapps/common/AoE3DE/ -> 933110)
  local installdir
  for installdir in "${!INSTALLDIR_TO_APPID[@]}"; do
    if [[ "$cmd" == *"/$installdir/"* ]]; then
      printf '%s' "${INSTALLDIR_TO_APPID[$installdir]}"
      return
    fi
  done
  printf ''
}

# Extract the exact game .exe token from a full command line.
# Prints e.g. "AoE3DE_s.exe" (case preserved). Empty if none.
# Full-path version below preserves the exact file token that is running.
get_game_exe_path() {
  local cmd="$1" tok base
  local candidates
  # Full token: contiguous non-space/non-quote chars ending in .exe (keeps / and \ ).
  candidates=$(grep -oiE '[^ "'"'"'<>; ]+\.exe' <<<"$cmd" || true)
  [[ -n "$candidates" ]] || return 1
  # Prefer LAST non-noise path (Proton cmdlines put the game last).
  local reversed pick=""
  reversed=$(printf '%s\n' "$candidates" | tac)
  while IFS= read -r tok; do
    [[ -n "$tok" ]] || continue
    # strip trailing junk like , ; : ) ] that often sticks to the token
    tok="${tok%,}"; tok="${tok%;}"; tok="${tok%:}"; tok="${tok%)}"; tok="${tok%]}"
    base="${tok##*/}"; base="${base##*\\}"
    if ! is_noise_exe "$base"; then
      pick="$tok"
      break
    fi
  done <<<"$reversed"
  if [[ -n "$pick" ]]; then
    printf '%s' "$pick"
    return 0
  fi
  return 1
}
get_game_exe() {
  local cmd="$1" p base
  p=$(get_game_exe_path "$cmd" || true)
  [[ -n "$p" ]] || return 1
  base="${p##*/}"; base="${base##*\\}"
  printf '%s' "$base"
}

matches_filter() {
  local exe="$1" steam="$2" cmd="$3" exepath="${4:-}"
  [[ -z "$filter" ]] && return 0
  if [[ $exact -eq 1 ]]; then
    grep -qi -- "^${filter}$" <<<"$exe" && return 0
    [[ -n "$exepath" ]] && grep -qi -- "^${filter}$" <<<"$exepath" && return 0
    [[ -n "$steam" ]] && grep -qi -- "^${filter}$" <<<"$steam" && return 0
    return 1
  else
    grep -qi -- "$filter" <<<"$exe" && return 0
    [[ -n "$exepath" ]] && grep -qi -- "$filter" <<<"$exepath" && return 0
    [[ -n "$steam" ]] && grep -qi -- "$filter" <<<"$steam" && return 0
    # also allow filtering by appid / full cmd
    grep -qi -- "$filter" <<<"$cmd" && return 0
    return 1
  fi
}

# Per-game MAIN marker: oldest (smallest) PID per AppID (or exe if no AppID) is MAIN.
declare -A MAIN_PID_FOR_KEY=()
register_candidate() {
  local key="$1" pid="$2"
  if [[ -z "${MAIN_PID_FOR_KEY[$key]:-}" || "$pid" -lt "${MAIN_PID_FOR_KEY[$key]}" ]]; then
    MAIN_PID_FOR_KEY["$key"]="$pid"
  fi
}
is_main_pid() {
  local key="$1" pid="$2"
  [[ "${MAIN_PID_FOR_KEY[$key]:-}" == "$pid" ]]
}

found=0
# Shared scanner: prints TAB-separated rows: pid\texe\texepath\tappid\tsteam\tcmd
scan_candidates() {
    for proc in /proc/[0-9]*; do
      pid="${proc#/proc/}"
      [[ "$pid" == "$SELF_PID" || "$pid" == "$SELF_PPIDs" ]] && continue
      [[ -r "$proc/cmdline" ]] || continue
      cmd=$(cat "$proc/cmdline" 2>/dev/null | tr '\0' ' ' 2>/dev/null || true)
      [[ -n "$cmd" ]] || continue
      if [[ "$cmd" == *"$SCRIPT_BASENAME"* ]]; then continue; fi

      exe_link=$(readlink "$proc/exe" 2>/dev/null || true)
      exe_base=$(basename "$exe_link" 2>/dev/null || true)

      appid=$(get_appid "$pid" "$cmd $exe_link")
      has_steamapps=0
      if [[ "$cmd" == *"steamapps/common"* || "$exe_link" == *"steamapps/common"* ]]; then
        has_steamapps=1
      fi

      game_exe=""
      game_path=""
      game_path=$(get_game_exe_path "$cmd" || true)
      if [[ -n "$game_path" ]]; then
        game_exe="${game_path##*/}"; game_exe="${game_exe##*\\}"
      fi

      # Native Linux game (no .exe): exact file = /proc/pid/exe target.
      if [[ -z "$game_exe" ]]; then
        if [[ $has_steamapps -eq 1 ]]; then
          arg0full=$(awk '{print $1}' <<<"$cmd")
          arg0=$(basename "$arg0full" 2>/dev/null || true)
          if [[ -n "$arg0" ]] && ! is_wrapper_basename "$arg0"; then
            game_exe="$arg0"
            # exact file: prefer exe_link if it is the steam file, else argv[0]
            if [[ "$exe_link" == *"steamapps"* ]]; then
              game_path="$exe_link"
            else
              game_path="$arg0full"
            fi
          elif [[ -n "$exe_base" ]] && ! is_wrapper_basename "$exe_base"; then
            game_exe="$exe_base"
            game_path="$exe_link"
          else
            continue
          fi
        else
          continue
        fi
      fi

      # Require Steam provenance (kills python/proton.vpn/zsh false positives).
      if [[ -z "$appid" && $has_steamapps -eq 0 ]]; then
        continue
      fi
      if is_wrapper_basename "$game_exe"; then
        continue
      fi

      steam_name=""
      if [[ -n "$appid" ]]; then
        steam_name=$(steam_name_for_appid "$appid" || true)
      fi

      if ! matches_filter "$game_exe" "$steam_name" "$cmd" "$game_path"; then
        continue
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$game_exe" "$game_path" "$appid" "$steam_name" "$cmd"
    done
}

if [[ $names_only -eq 1 || $paths_only -eq 1 ]]; then
  declare -A seen=()
  while IFS=$'\t' read -r pid game_exe game_path appid steam_name cmd; do
    [[ -n "${game_exe:-}" ]] || continue
    if [[ $paths_only -eq 1 ]]; then
      [[ -n "${game_path:-}" ]] || continue
      seen["$game_path"]="$game_path"
    else
      seen["${game_exe,,}"]="$game_exe"
    fi
  done < <(scan_candidates)

  if [[ ${#seen[@]} -gt 0 ]]; then
    found=1
    for name in "${seen[@]}"; do
      printf '%s\n' "$name"
    done | sort
  fi
else
  ROWS=()
  while IFS=$'\t' read -r pid game_exe game_path appid steam_name cmd; do
    ROWS+=("$pid"$'\t'"$game_exe"$'\t'"$game_path"$'\t'"$appid"$'\t'"$steam_name"$'\t'"$cmd")
    if [[ -n "$appid" ]]; then
      register_candidate "appid:$appid" "$pid"
    else
      register_candidate "exe:${game_exe,,}" "$pid"
    fi
  done < <(scan_candidates)

  if [[ ${#ROWS[@]} -gt 0 ]]; then
    found=1
    # MAIN first, then by PID so the main game exe is on top.
    SORTED=$(printf '%s\n' "${ROWS[@]}" | sort -t $'\t' -k1,1n)
    while IFS=$'\t' read -r pid game_exe game_path appid steam_name cmd; do
      if [[ -n "$appid" ]]; then key="appid:$appid"; else key="exe:${game_exe,,}"; fi
      tag="CHILD"
      if is_main_pid "$key" "$pid"; then tag="MAIN"; fi
      if [[ $show_full -eq 1 ]]; then
        printf '%s\tPID=%s\tEXE=%s\tFILE=%s\tAppID=%s\tSteam=%s\tCMD=%s\n' \
          "$tag" "$pid" "$game_exe" "${game_path:-?}" "${appid:-?}" "${steam_name:-?}" "$cmd"
      elif [[ $pid_only -eq 1 ]]; then
        printf '%s\n' "$pid"
      else
        if [[ -n "$steam_name" ]]; then
          printf '%s\t%s\tPID=%s\tFILE=%s\tAppID=%s\tSteam=%s\n' \
            "$tag" "$game_exe" "$pid" "${game_path:-?}" "${appid:-?}" "$steam_name"
        else
          printf '%s\t%s\tPID=%s\tFILE=%s\n' "$tag" "$game_exe" "$pid" "${game_path:-?}"
        fi
      fi
    done <<<"$SORTED"
  fi
fi

if [[ $found -eq 0 ]]; then
  echo "No matching game process found." >&2
  exit 1
fi
