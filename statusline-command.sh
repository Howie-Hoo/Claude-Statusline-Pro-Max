#!/usr/bin/env bash
# Claude Code status line — responsive layout
# Zones: Model | Context | Workspace | Duration
# Responsive: adapts to terminal width with progressive truncation

input=$(cat)

# ── Extract fields: jq outputs shell variable assignments, eval them ──
# Gracefully handle empty/malformed input by wrapping in default object
if ! parsed=$(jq -r '
  "model_id=" + (.model.id // "unknown" | @sh),
  "model_name=" + (.model.display_name // "unknown" | @sh),
  "used_pct=" + (.context_window.used_percentage // 0 | tostring),
  "ctx_size=" + (.context_window.context_window_size // 0 | tostring),
  "input_tok=" + (.context_window.current_usage.input_tokens // 0 | tostring),
  "output_tok=" + (.context_window.current_usage.output_tokens // 0 | tostring),
  "cache_create=" + (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
  "cache_read=" + (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
  "cwd=" + (.workspace.current_dir // .cwd // "" | @sh),
  "project_dir=" + (.workspace.project_dir // "" | @sh),
  "git_worktree=" + (.workspace.git_worktree // "" | @sh),
  "wt_branch=" + (.worktree.branch // "" | @sh),
  "duration_ms=" + (.cost.total_duration_ms // 0 | tostring),
  "effort_level=" + (.effort.level // "" | @sh),
  "thinking_enabled=" + (.thinking.enabled // false | tostring),
  "rate_5h=" + (.rate_limits.five_hour.used_percentage // "" | @sh),
  "rate_7d=" + (.rate_limits.seven_day.used_percentage // "" | @sh),
  "agent_name=" + (.agent.name // "" | @sh),
  "worktree_name=" + (.worktree.name // "" | @sh),
  "vim_mode=" + (.vim.mode // "" | @sh)
' <<< "$input" 2>/dev/null) || [ -z "$parsed" ]; then
  model_id="unknown"; model_name="unknown"; used_pct=0; ctx_size=0
  input_tok=0; output_tok=0; cache_create=0; cache_read=0
  cwd=""; project_dir=""; git_worktree=""; wt_branch=""
  duration_ms=0; effort_level=""; thinking_enabled="false"
  rate_5h=""; rate_7d=""; agent_name=""; worktree_name=""; vim_mode=""
else
  eval "$parsed"
fi

# ── Colors ──
RST='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[31m'; GRN='\033[32m'; YLW='\033[33m'
BLU='\033[34m'; MGN='\033[35m'; CYN='\033[36m'; GRY='\033[90m'

# ── Terminal width ──
term_cols=$(stty size < /dev/tty 2>/dev/null | cut -d' ' -f2)
[ -z "$term_cols" ] || [ "$term_cols" -eq 0 ] 2>/dev/null && term_cols=$(tput cols 2>/dev/null)
[ -z "$term_cols" ] || [ "$term_cols" -eq 0 ] 2>/dev/null && term_cols=120

# ── Visible length: strip ANSI escape sequences, account for CJK/emoji width ──
# Color vars store literal \033[...m strings; strip those before counting
# Exact formula for ASCII + CJK + emoji: display = chars + (bytes - chars - N_4byte) / 2
# where N_4byte = count of 4-byte UTF-8 leading bytes (F0-F4 = emoji/rare CJK)
# This is exact when N_2byte ≈ 0 (true for typical paths); overestimates by ≤1
# for rare 2-byte chars (Latin-1), which is safe (truncates more, not less).
visible_len() {
  local s="$1"
  s="${s//\\033\[0m/}";  s="${s//\\033\[1m/}";  s="${s//\\033\[2m/}"
  s="${s//\\033\[31m/}"; s="${s//\\033\[32m/}"; s="${s//\\033\[33m/}"
  s="${s//\\033\[34m/}"; s="${s//\\033\[35m/}"; s="${s//\\033\[36m/}"
  s="${s//\\033\[90m/}"
  local char_count byte_count n4
  char_count=${#s}
  byte_count=$(printf '%s' "$s" | wc -c | tr -d ' ')
  n4=$(printf '%s' "$s" | od -A n -t x1 | tr ' ' '\n' | grep -cE '^f[0-4]$')
  echo $(( char_count + (byte_count - char_count - n4) / 2 ))
}

# ── Token formatting (pure bash arithmetic) ──
fmt_tok() {
  local t=$1
  if [ "$t" -ge 1000000 ]; then
    printf "%d.%dM" "$(( t / 1000000 ))" "$(( (t % 1000000) / 100000 ))"
  elif [ "$t" -ge 1000 ]; then
    printf "%d.%dk" "$(( t / 1000 ))" "$(( (t % 1000) / 100 ))"
  else
    printf "%d" "$t"
  fi
}

# ── Zone 1: Model ──
case "$model_id" in
  *opus*)  m_color=$MGN ;;
  *sonnet*) m_color=$BLU ;;
  *haiku*)  m_color=$CYN ;;
  *)        m_color=$GRN ;;
esac

think_mark=""
[ "$thinking_enabled" = "true" ] && think_mark=" ${BOLD}${GRN}●${RST}"

effort_mark=""
case "$effort_level" in
  low)    effort_mark=" ${DIM}l${RST}" ;;
  medium) effort_mark=" ${DIM}m${RST}" ;;
  high)   effort_mark=" ${GRY}h${RST}" ;;
  xhigh)  effort_mark=" ${BOLD}x${RST}" ;;
  max)    effort_mark=" ${BOLD}M${RST}" ;;
esac

agent_mark=""
[ -n "$agent_name" ] && agent_mark=" ${GRY}@${agent_name:0:8}${RST}"

# Model name truncation levels
m_full="$model_name"
if [[ "$model_name" == *-* ]]; then
  # Dash names: preserve at mid level, truncate only at short level
  m_mid="$model_name"
  m_short="$model_name"
  [ ${#model_name} -gt 12 ] && m_short="${model_name:0:11}…"
else
  m_mid="$model_name"
  [ ${#model_name} -gt 12 ] && m_mid="${model_name:0:11}…"
  m_short="$model_name"
  [ ${#model_name} -gt 6 ] && m_short="${model_name:0:5}…"
fi

# ── Zone 2: Context ──
if [ -n "$used_pct" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  pct_int=${used_pct%.*}
  [ -z "$pct_int" ] && pct_int=0
  # Clamp to [0, 100] for bar and color logic
  [ "$pct_int" -lt 0 ] && pct_int=0
  [ "$pct_int" -gt 100 ] && pct_int=100

  if [ "$pct_int" -gt 85 ]; then ctx_color=$RED
  elif [ "$pct_int" -gt 69 ]; then ctx_color=$YLW
  else ctx_color=$GRN
  fi

  used_tok=$(( input_tok + output_tok + cache_create + cache_read ))
  used_f=$(fmt_tok "$used_tok")
  total_f=$(fmt_tok "$ctx_size")

  # Progress bar: 10 cells, clamped
  filled=$(( pct_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}▓"; i=$((i + 1)); done
  i=0; while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i + 1)); done

  # Display original percentage (not clamped) for accuracy
  ctx_full="${ctx_color}${bar}${RST} ${ctx_color}${used_pct}%${RST} ${DIM}${used_f}/${total_f}${RST}"
  ctx_mid="${ctx_color}${used_pct}%${RST} ${DIM}${used_f}/${total_f}${RST}"
  ctx_short="${ctx_color}${used_pct}%${RST}"
else
  ctx_full="${DIM}░░░░░░░░░░ n/a${RST}"
  ctx_mid="${DIM}ctx n/a${RST}"
  ctx_short="${DIM}n/a${RST}"
fi

# ── Zone 3: Workspace ──
# Use project_dir to extract meaningful project name + relative path
if [ -z "$cwd" ]; then
  path_full="—"; path_mid="—"; path_short="—"
elif [[ "$cwd" == "$HOME"* ]]; then
  short_cwd="~${cwd#$HOME}"
else
  short_cwd="$cwd"
fi

# Derive project name from project_dir (official field from Claude Code)
# Only use when project_dir is a real project (not $HOME) and cwd is under it
# Strip trailing slash for consistent matching
project_name=""
if [ -n "$project_dir" ] && [ "$project_dir" != "$HOME" ]; then
  project_dir="${project_dir%/}"
  if [ "$project_dir" != "$HOME" ] && { [[ "$cwd" == "$project_dir" ]] || [[ "$cwd" == "$project_dir/"* ]]; }; then
    project_name="${project_dir##*/}"
  fi
fi

# Derive relative path from project_dir to cwd
rel_path=""
if [ -n "$project_name" ] && [ "$cwd" != "$project_dir" ]; then
  rel_path="${cwd#"$project_dir"/}"
fi

# Three truncation levels for path
if [ -n "$project_name" ] && [ -n "$rel_path" ]; then
  # Best case: project_name/rel_path (e.g., "Zao Shen/zaoshen-console")
  path_full="${project_name}/${rel_path}"
  # Mid: project_name + last segment of rel_path
  if [[ "$rel_path" == */* ]]; then
    last_rel="${rel_path##*/}"
    path_mid="${project_name}/…/${last_rel}"
  else
    path_mid="${project_name}/${rel_path}"
  fi
  # Short: project_name only (most meaningful identifier), capped at 15 chars
  path_short="$project_name"
  [ ${#path_short} -gt 15 ] && path_short="${project_name:0:14}…"
elif [ -n "$project_name" ]; then
  # cwd == project_dir (at project root)
  path_full="$project_name"
  [ ${#path_full} -gt 30 ] && path_full="${project_name:0:29}…"
  path_mid="$project_name"
  [ ${#path_mid} -gt 20 ] && path_mid="${project_name:0:19}…"
  path_short="$project_name"
  [ ${#path_short} -gt 15 ] && path_short="${project_name:0:14}…"
else
  # Fallback: no project_dir available
  path_full="$short_cwd"
  if [[ "$short_cwd" == */*/* ]]; then
    first_seg="${short_cwd%%/*}"
    last_seg="${short_cwd##*/}"
    [ ${#last_seg} -gt 12 ] && last_seg="${last_seg:0:11}…"
    path_mid="${first_seg}/…/${last_seg}"
  elif [[ "$short_cwd" == */* ]]; then
    last_seg="${short_cwd##*/}"
    [ ${#last_seg} -gt 15 ] && last_seg="${last_seg:0:14}…"
    path_mid="…/${last_seg}"
  else
    path_mid="$short_cwd"
  fi
  path_short="${short_cwd##*/}"
  [ ${#path_short} -gt 15 ] && path_short="${path_short:0:14}…"
fi

# Git branch: prefer schema fields, fallback to git command with cache
branch=""
if [ -n "$wt_branch" ]; then
  branch="$wt_branch"
elif [ -n "$git_worktree" ]; then
  branch="$git_worktree"
elif [ -n "$worktree_name" ]; then
  branch="$worktree_name"
else
  cache_file="/tmp/.claude-git-branch-$(echo -n "$cwd" | md5)"
  cache_age=0
  if [ -f "$cache_file" ]; then
    now=$(date +%s)
    mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
    cache_age=$(( now - mtime ))
  fi
  if [ "$cache_age" -gt 5 ] || [ ! -f "$cache_file" ]; then
    git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null > "$cache_file" || \
    git -C "$cwd" rev-parse --short HEAD 2>/dev/null > "$cache_file" || \
    echo "" > "$cache_file"
  fi
  branch=$(cat "$cache_file" 2>/dev/null)
fi

branch_full="$branch"
if [ -n "$branch" ] && [ ${#branch} -gt 12 ]; then
  branch_short="${branch:0:11}…"
else
  branch_short="$branch"
fi

# Vim mode indicator
vim_mark=""
case "$vim_mode" in
  NORMAL)       vim_mark=" ${GRY}[N]${RST}" ;;
  INSERT)       vim_mark=" ${GRN}[I]${RST}" ;;
  VISUAL)       vim_mark=" ${YLW}[V]${RST}" ;;
  "VISUAL LINE") vim_mark=" ${YLW}[V-L]${RST}" ;;
esac

# ── Zone 4: Duration ──
dur_str=""
if [ -n "$duration_ms" ] && [ "$duration_ms" -gt 0 ] 2>/dev/null; then
  dur_s=$(( duration_ms / 1000 ))
  if [ "$dur_s" -ge 86400 ]; then
    dur_d=$(( dur_s / 86400 ))
    dur_h=$(( (dur_s % 86400) / 3600 ))
    dur_str="${dur_d}d"
    [ "$dur_h" -gt 0 ] && dur_str="${dur_str}${dur_h}h"
  elif [ "$dur_s" -ge 3600 ]; then
    dur_h=$(( dur_s / 3600 ))
    dur_m=$(( (dur_s % 3600) / 60 ))
    dur_str="${dur_h}h"
    [ "$dur_m" -gt 0 ] && dur_str="${dur_str}${dur_m}m"
  elif [ "$dur_s" -ge 60 ]; then
    dur_m=$(( dur_s / 60 ))
    dur_s_rem=$(( dur_s % 60 ))
    dur_str="${dur_m}m"
    [ "$dur_s_rem" -gt 0 ] && dur_str="${dur_str}${dur_s_rem}s"
  elif [ "$dur_s" -ge 1 ]; then
    dur_str="${dur_s}s"
  fi
fi

rate_str=""
if [ -n "$rate_5h" ]; then
  r5h_int=${rate_5h%.*}; [ -z "$r5h_int" ] && r5h_int=0
  # Guard against non-numeric values
  [ "$r5h_int" -eq "$r5h_int" ] 2>/dev/null || r5h_int=0
  if [ "$r5h_int" -gt 80 ]; then r5h_color=$RED
  elif [ "$r5h_int" -gt 49 ]; then r5h_color=$YLW
  else r5h_color=$GRN
  fi
  rate_str="${r5h_color}5h:${r5h_int}%${RST}"
fi
if [ -n "$rate_7d" ]; then
  r7d_int=${rate_7d%.*}; [ -z "$r7d_int" ] && r7d_int=0
  [ "$r7d_int" -eq "$r7d_int" ] 2>/dev/null || r7d_int=0
  if [ "$r7d_int" -gt 80 ]; then r7d_color=$RED
  elif [ "$r7d_int" -gt 49 ]; then r7d_color=$YLW
  else r7d_color=$GRN
  fi
  [ -n "$rate_str" ] && rate_str="${rate_str} "
  rate_str="${rate_str}${r7d_color}7d:${r7d_int}%${RST}"
fi

# ── Responsive assembly ──
# Truncation priority: progress bar < model name < branch
# Optional element priority: rate limits < vim mode < duration
# Path truncation interleaved as secondary space saver
sep="${GRY} │ ${RST}"

# try_build: model path branch context show_rate show_vim show_dur
# show_rate/show_vim/show_dur: "1" to include, "0" to omit
try_build() {
  local m="$1" p="$2" b="$3" c="$4" sr="$5" sv="$6" sd="$7"
  local result="${m_color}${BOLD}${m}${RST}${think_mark}${effort_mark}${agent_mark}${sep}${c}"
  # Path zone: only add separator + path if path is non-empty
  if [ -n "$p" ]; then
    result="${result}${sep}${CYN}${p}${RST}"
  fi
  # Branch: when path is empty, prefix with git symbol for visual distinction
  if [ -n "$b" ]; then
    if [ -n "$p" ]; then
      result="${result} ${YLW}${b}${RST}"
    else
      result="${result}${sep}${YLW}${b}${RST}"
    fi
  fi
  [ "$sv" = "1" ] && result="${result}${vim_mark}"
  # Duration zone: only add separator + duration if duration is non-empty or rate is shown
  if [ "$sd" = "1" ] && [ -n "$dur_str" ]; then
    result="${result}${sep}${GRY}${dur_str}${RST}"
  elif [ "$sr" = "1" ] && [ -n "$rate_str" ]; then
    result="${result}${sep}"
  fi
  if [ "$sr" = "1" ] && [ -n "$rate_str" ]; then
    if [ "$sd" = "0" ] || [ -z "$dur_str" ]; then
      result="${result}${rate_str}"
    else
      result="${result} ${rate_str}"
    fi
  fi
  printf '%s' "$result"
}

# L0: full model + full path + full branch + bar+%+token + all optional
candidate=$(try_build "$m_full" "$path_full" "$branch_full" "$ctx_full" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L1: full model + mid path + full branch + bar+%+token + all optional
candidate=$(try_build "$m_full" "$path_mid" "$branch_full" "$ctx_full" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L2: full model + mid path + full branch + %+token (bar removed)
candidate=$(try_build "$m_full" "$path_mid" "$branch_full" "$ctx_mid" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L3: full model + short path + full branch + %+token
candidate=$(try_build "$m_full" "$path_short" "$branch_full" "$ctx_mid" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L4: mid model + short path + full branch + %+token
candidate=$(try_build "$m_mid" "$path_short" "$branch_full" "$ctx_mid" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L5: mid model + short path + short branch + %+token
candidate=$(try_build "$m_mid" "$path_short" "$branch_short" "$ctx_mid" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L6: short model + short path + short branch + %+token
candidate=$(try_build "$m_short" "$path_short" "$branch_short" "$ctx_mid" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L7: short model + short path + short branch + % only
candidate=$(try_build "$m_short" "$path_short" "$branch_short" "$ctx_short" 1 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# ── Progressive optional element removal ──
# Drop least critical optional elements first to preserve core info

# L8: drop rate limits (least critical — only matters near limits)
candidate=$(try_build "$m_short" "$path_short" "$branch_short" "$ctx_short" 0 1 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L9: drop rate + vim (vim is nice-to-have, not essential)
candidate=$(try_build "$m_short" "$path_short" "$branch_short" "$ctx_short" 0 0 1)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L10: drop rate + vim + duration (keep path — most important context)
candidate=$(try_build "$m_short" "$path_short" "$branch_short" "$ctx_short" 0 0 0)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# L11: drop path too (model + context % + branch only)
candidate=$(try_build "$m_short" "" "$branch_short" "$ctx_short" 0 0 0)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# Fallback: model + context % only (no path, no branch)
candidate=$(try_build "$m_short" "" "" "$ctx_short" 0 0 0)
if [ "$(visible_len "$candidate")" -le "$term_cols" ]; then
  printf "%b" "$candidate"; exit 0
fi

# Emergency: model name only (for extremely narrow terminals)
emergency="${m_color}${BOLD}${m_short}${RST}"
if [ "$(visible_len "$emergency")" -le "$term_cols" ]; then
  printf "%b" "$emergency"; exit 0
fi
# Last resort: first N chars of model name (no ellipsis, no color)
raw="${model_name:0:$((term_cols > 0 ? term_cols : 1))}"
printf '%s' "$raw"