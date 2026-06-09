#!/usr/bin/env bash
# Claude Code status line — responsive layout
# Zones: Model | Context | Workspace | Duration
# Responsive: adapts to terminal width with progressive truncation

input=$(cat)

# ── Extract fields: jq outputs shell variable assignments, eval them ──
# Gracefully handle empty/malformed input by wrapping in default object
# All numeric fields use floor to guarantee integer output (jq tostring
# on floats like 200000.0 would crash bash arithmetic)
if ! parsed=$(jq -r '
  "model_id=" + (.model.id // "unknown" | @sh),
  "model_name=" + (.model.display_name // "unknown" | @sh),
  "used_pct=" + (.context_window.used_percentage // 0 | floor | tostring),
  "ctx_size=" + (.context_window.context_window_size // 0 | floor | tostring),
  "input_tok=" + (.context_window.current_usage.input_tokens // 0 | floor | tostring),
  "output_tok=" + (.context_window.current_usage.output_tokens // 0 | floor | tostring),
  "cache_create=" + (.context_window.current_usage.cache_creation_input_tokens // 0 | floor | tostring),
  "cache_read=" + (.context_window.current_usage.cache_read_input_tokens // 0 | floor | tostring),
  "cwd=" + (.workspace.current_dir // .cwd // "" | @sh),
  "project_dir=" + (.workspace.project_dir // "" | @sh),
  "git_worktree=" + (.workspace.git_worktree // "" | @sh),
  "wt_branch=" + (.worktree.branch // "" | @sh),
  "duration_ms=" + (.cost.total_duration_ms // 0 | floor | tostring),
  "effort_level=" + (.effort.level // "" | @sh),
  "thinking_enabled=" + (.thinking.enabled // false | tostring),
  "thinking_type=" + (.thinking.type // "" | @sh),
  "fast_mode=" + (.fast_mode // false | tostring),
  "exceeds_200k=" + (.exceeds_200k_tokens // false | tostring),
  "lines_added=" + (.cost.total_lines_added // 0 | floor | tostring),
  "lines_removed=" + (.cost.total_lines_removed // 0 | floor | tostring),
  "rate_5h=" + (.rate_limits.five_hour.used_percentage // "" | @sh),
  "rate_7d=" + (.rate_limits.seven_day.used_percentage // "" | @sh),
  "agent_name=" + (.agent.name // "" | @sh),
  "worktree_name=" + (.worktree.name // "" | @sh),
  "vim_mode=" + (.vim.mode // "" | @sh),
  "remote_session=" + (.remote.session_id // "" | @sh),
  "pr_number=" + (.pr.number // 0 | floor | tostring)
' <<< "$input" 2>/dev/null) || [ -z "$parsed" ]; then
  model_id="unknown"; model_name="unknown"; used_pct=0; ctx_size=0
  input_tok=0; output_tok=0; cache_create=0; cache_read=0
  cwd=""; project_dir=""; git_worktree=""; wt_branch=""
  duration_ms=0; effort_level=""; thinking_enabled="false"; thinking_type=""
  fast_mode="false"; exceeds_200k="false"; lines_added=0; lines_removed=0
  rate_5h=""; rate_7d=""; agent_name=""; worktree_name=""; vim_mode=""
  remote_session=""; pr_number=0
else
  eval "$parsed"
  # Sanitize newlines — single-line statusbar invariant
  model_name="${model_name//$'\n'/ }"
  agent_name="${agent_name//$'\n'/ }"
  cwd="${cwd//$'\n'/ }"
fi

# ── Colors ──
RST=$'\033'[0m; BOLD=$'\033'[1m; DIM=$'\033'[2m
RED=$'\033'[31m; GRN=$'\033'[32m; YLW=$'\033'[33m
BLU=$'\033'[34m; MGN=$'\033'[35m; CYN=$'\033'[36m; GRY=$'\033'[90m

# ── Terminal width ──
_term_size=$(stty size < /dev/tty 2>/dev/null)
term_cols=${_term_size#* }
[ -z "$term_cols" ] || [ "$term_cols" -eq 0 ] 2>/dev/null && term_cols=$(tput cols 2>/dev/null)
[ -z "$term_cols" ] || [ "$term_cols" -eq 0 ] 2>/dev/null && term_cols=120

# ── Visible length: strip ANSI escape sequences, account for CJK/emoji width ──
# Color vars store literal \033[...m strings; strip those before counting
# Formula: display = chars + (bytes - chars - N_4byte) / 2 - N_3byte_single_width
#   N_4byte = count of 4-byte UTF-8 leading bytes (F0-F4 = emoji/rare CJK), each is 2-col
#   N_3byte_single_width = count of known 3-byte 1-col chars (│▓░●…)
# The base formula treats all 3-byte chars as 2-col CJK; subtracting N_3sw corrects
# the overcount for box-drawing/block-element/punctuation chars that are actually 1-col.
visible_len() {
  local s="$1"
  local _esc=$'\033'
  s="${s//${_esc}\[0m/}";  s="${s//${_esc}\[1m/}";  s="${s//${_esc}\[2m/}"
  s="${s//${_esc}\[31m/}"; s="${s//${_esc}\[32m/}"; s="${s//${_esc}\[33m/}"
  s="${s//${_esc}\[34m/}"; s="${s//${_esc}\[35m/}"; s="${s//${_esc}\[36m/}"
  s="${s//${_esc}\[90m/}"
  local char_count byte_count n4 n3sw _old_lc _only_n4 _t
  char_count=${#s}
  _old_lc="$LC_ALL"; LC_ALL=C; byte_count=${#s}; LC_ALL="$_old_lc"
  _old_lc="$LC_ALL"; LC_ALL=C
  _only_n4="${s//[^$'\xf0'$'\xf1'$'\xf2'$'\xf3'$'\xf4']/}"
  n4=${#_only_n4}
  LC_ALL="$_old_lc"
  n3sw=0
  _t="${s//│/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _t="${s//▓/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _t="${s//░/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _t="${s//●/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _t="${s//◉/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _t="${s//◆/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _t="${s//⚠/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _t="${s//…/}"; n3sw=$(( n3sw + (char_count - ${#_t}) ))
  _VL=$(( char_count + (byte_count - char_count - n4) / 2 - n3sw ))
}

# ── Token formatting (pure bash arithmetic) ──
fmt_tok() {
  local t=$1
  [ -z "$t" ] && { _FT="0"; return; }
  if [ "$t" -ge 1000000 ]; then
    _FT="$(( t / 1000000 )).$(( (t % 1000000) / 100000 ))M"
  elif [ "$t" -ge 1000 ]; then
    _FT="$(( t / 1000 )).$(( (t % 1000) / 100 ))k"
  else
    _FT="$t"
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
if [ "$thinking_type" = "adaptive" ]; then
  think_mark=" ${BOLD}${GRN}◉${RST}"
elif [ "$thinking_enabled" = "true" ]; then
  think_mark=" ${BOLD}${GRN}●${RST}"
fi

effort_mark=""
case "$effort_level" in
  low)       effort_mark=" ${DIM}l${RST}" ;;
  medium)    effort_mark=" ${DIM}m${RST}" ;;
  high)      effort_mark=" ${GRY}h${RST}" ;;
  xhigh)     effort_mark=" ${BOLD}x${RST}" ;;
  ultracode) effort_mark=" ${BOLD}${MGN}◆${RST}" ;;
  max)       effort_mark=" ${BOLD}M${RST}" ;;
esac

fast_mark=""
[ "$fast_mode" = "true" ] && fast_mark=" ${YLW}⚡${RST}"

remote_mark=""
[ -n "$remote_session" ] && remote_mark=" ${DIM}🌐${RST}"

agent_mark=""
[ -n "$agent_name" ] && agent_mark=" ${GRY}@${agent_name:0:8}${RST}"

# Model name truncation levels
m_full="$model_name"
# Extract family keyword for family-preserving truncation
_model_family=""
case "$model_id" in
  *opus*)  _model_family="opus" ;;
  *sonnet*) _model_family="sonnet" ;;
  *haiku*)  _model_family="haiku" ;;
esac

if [[ "$model_name" == *-* ]]; then
  # Dash names: mid level preserves family + version (e.g. "3-5-sonnet", "opus-4-7")
  # Strategy: find the family keyword in the name, keep from the segment before it
  if [ -n "$_model_family" ]; then
    # Find the segment containing the family keyword, keep version chain around it
    # e.g. "claude-3-5-sonnet-20241022" → "3-5-sonnet", "claude-opus-4-7" → "opus-4-7"
    _remaining="$model_name"
    _prev2_seg="" _prev_seg=""
    while [[ "$_remaining" == *-* ]]; do
      _seg="${_remaining%%-*}"
      _remaining="${_remaining#*-}"
      if [[ "$_seg" == *"$_model_family"* ]]; then
        # Include up to 2 version segments before the family keyword
        # but skip "claude" prefix (it's noise — the family keyword is the identifier)
        _found_family=""
        if [ -n "$_prev2_seg" ] && [ "$_prev_seg" != "claude" ]; then
          _found_family="$_prev2_seg-"
        fi
        if [ -n "$_prev_seg" ] && [ "$_prev_seg" != "claude" ]; then
          _found_family="${_found_family}${_prev_seg}-"
        fi
        _found_family="${_found_family}${_seg}"
        # Also include up to 2 segments after (version numbers like "4-7")
        _after_count=0
        while [ -n "$_remaining" ] && [ "$_after_count" -lt 2 ]; do
          if [[ "$_remaining" == *-* ]]; then
            _next_seg="${_remaining%%-*}"
            _remaining="${_remaining#*-}"
          else
            _next_seg="$_remaining"
            _remaining=""
          fi
          # Skip date-like segments (8+ consecutive digits)
          [[ "$_next_seg" =~ ^[0-9]{8,}$ ]] && continue
          _found_family="${_found_family}-${_next_seg}"
          _after_count=$(( _after_count + 1 ))
        done
        break
      fi
      _prev2_seg="$_prev_seg"
      _prev_seg="$_seg"
    done
    if [ -n "$_found_family" ]; then
      if [ ${#_found_family} -le 12 ]; then
        m_mid="$_found_family"
      else
        m_mid="${_found_family:0:11}…"
      fi
    else
      # Fallback: family not found in segments, use last segment
      _after_last_dash="${model_name##*-}"
      if [ ${#_after_last_dash} -le 12 ]; then
        m_mid="$_after_last_dash"
      else
        m_mid="${_after_last_dash:0:11}…"
      fi
    fi
  else
    # No family keyword, use last dash segment
    _after_last_dash="${model_name##*-}"
    if [ ${#_after_last_dash} -le 12 ]; then
      m_mid="$_after_last_dash"
    else
      m_mid="${_after_last_dash:0:11}…"
    fi
  fi
  # Short level: family name only (most identifiable part)
  if [ -n "$_model_family" ]; then
    m_short="$_model_family"
  else
    m_short="$model_name"
    [ ${#model_name} -gt 6 ] && m_short="${model_name:0:5}…"
  fi
else
  m_mid="$model_name"
  [ ${#model_name} -gt 12 ] && m_mid="${model_name:0:11}…"
  m_short="$model_name"
  [ ${#model_name} -gt 6 ] && m_short="${model_name:0:5}…"
fi

# ── Zone 2: Context ──
# Signal quality tiers:
#   TIER 1 (real):    current_usage tokens are non-zero → exact usage
#   TIER 2 (partial): current_usage all zero but used_pct > 0 → percentage + bar, no token counts
#   TIER 3 (unknown): only ctx_size known → show size, no percentage, no bar
#   TIER 0 (none):    no data at all → n/a
#
# Rationale: total_input_tokens/total_output_tokens (as of v2.1.132) reflect
# current context usage only, not cumulative session totals — redundant with
# the token counts already shown in TIER 1. Session tokens removed from
# Zone 4 to avoid duplicate information.
#
# Overflow warning: when context usage approaches the model's window size,
# auto-compaction may be triggered or (if exceeds_200k) disabled entirely.
# Warning thresholds are proportional to the actual context_window_size:
# Color thresholds: green ≤69%, yellow 70-85%, red >85%.
# When exceeds_200k_tokens=true and usage >85%, force red (no safety net).
used_tok=$(( input_tok + output_tok + cache_create + cache_read ))
ctx_tier=0

if [ "$used_tok" -gt 0 ] 2>/dev/null && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  # TIER 1: We have real current_usage tokens
  ctx_tier=1
  if [ "$used_pct" -eq 0 ] 2>/dev/null; then
    used_pct=$(( used_tok * 100 / ctx_size ))
  fi
elif [ "$used_pct" -gt 0 ] 2>/dev/null && [ "$ctx_size" -gt 0 ]; then
  # TIER 2: We have used_percentage but no current_usage tokens
  ctx_tier=2
elif [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  # TIER 3: Only context size is known, no usage signal
  ctx_tier=3
fi

# Shared pct_int clamping, color selection, and progress bar for TIER 1 and TIER 2
if [ "$ctx_tier" -ge 1 ]; then
  pct_int=${used_pct%.*}
  [ -z "$pct_int" ] && pct_int=0
  [ "$pct_int" -lt 0 ] && pct_int=0
  [ "$pct_int" -gt 100 ] && pct_int=100
  if [ "$pct_int" -gt 85 ]; then ctx_color=$RED
  elif [ "$pct_int" -gt 69 ]; then ctx_color=$YLW
  else ctx_color=$GRN
  fi
  filled=$(( pct_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}▓"; i=$((i + 1)); done
  i=0; while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i + 1)); done
fi

if [ "$ctx_tier" -eq 1 ]; then
  # ── TIER 1: Full fidelity display ──
  fmt_tok "$used_tok"; used_f=$_FT
  fmt_tok "$ctx_size"; total_f=$_FT

  ctx_full="${ctx_color}${bar}${RST} ${ctx_color}${used_pct}%${RST} ${DIM}${used_f}/${total_f}${RST}"
  ctx_mid="${ctx_color}${used_pct}%${RST} ${DIM}${used_f}/${total_f}${RST}"
  ctx_short="${ctx_color}${used_pct}%${RST}"

elif [ "$ctx_tier" -eq 2 ]; then
  # ── TIER 2: Percentage + bar (derived from used_pct), no token counts ──
  fmt_tok "$ctx_size"; total_f=$_FT

  ctx_full="${ctx_color}${bar}${RST} ${ctx_color}${used_pct}%${RST} ${DIM}${total_f}${RST}"
  ctx_mid="${ctx_color}${used_pct}%${RST} ${DIM}${total_f}${RST}"
  ctx_short="${ctx_color}${used_pct}%${RST}"

elif [ "$ctx_tier" -eq 3 ]; then
  # ── TIER 3: Context size only ──
  fmt_tok "$ctx_size"; total_f=$_FT
  ctx_full="${GRY}ctx ${total_f}${RST}"
  ctx_mid="${GRY}ctx ${total_f}${RST}"
  ctx_short="${GRY}${total_f}${RST}"

else
  # ── TIER 0: No data at all ──
  ctx_full="${DIM}░░░░░░░░░░ n/a${RST}"
  ctx_mid="${DIM}ctx n/a${RST}"
  ctx_short="${DIM}n/a${RST}"
fi

# ── Zone 3: Workspace ──
# Use project_dir to extract meaningful project name + relative path
path_full="" path_mid="" path_short=""
if [ -z "$cwd" ]; then
  : # no workspace info — zones will be empty (omitted from layout)
elif [[ "$cwd" == "$HOME/"* || "$cwd" == "$HOME" ]]; then
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
  # Mid: truncated project_name + last segment of rel_path
  # Truncate project_name to 20 chars so path_mid stays reasonable
  if [ ${#project_name} -gt 20 ]; then
    _pn_mid="${project_name:0:19}…"
  else
    _pn_mid="$project_name"
  fi
  if [[ "$rel_path" == */* ]]; then
    last_rel="${rel_path##*/}"
    path_mid="${_pn_mid}/…/${last_rel}"
  else
    path_mid="${_pn_mid}/${rel_path}"
  fi
  # Short: project_name only (most meaningful identifier), capped at 15 chars
  path_short="$project_name"
  [ ${#path_short} -gt 15 ] && path_short="${project_name:0:14}…"
elif [ -n "$project_name" ]; then
  # cwd == project_dir (at project root)
  path_full="$project_name"
  # Mid: truncate if > 20 chars
  if [ ${#project_name} -gt 20 ]; then
    path_mid="${project_name:0:19}…"
  else
    path_mid="$project_name"
  fi
  # Short: truncate if > 12 chars
  if [ ${#project_name} -gt 12 ]; then
    path_short="${project_name:0:11}…"
  else
    path_short="$project_name"
  fi
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

# Git info: branch + version tag, merged cache
# Schema fields take priority; cache file stores both values (2 lines)
branch=""
version_tag=""
if [ -n "$wt_branch" ]; then
  branch="$wt_branch"
elif [ -n "$git_worktree" ]; then
  branch="$git_worktree"
elif [ -n "$worktree_name" ]; then
  branch="$worktree_name"
fi

if [ -n "$cwd" ]; then
  _cwd_hash=$(printf '%s' "$cwd" | (md5sum 2>/dev/null || md5) | cut -c1-32)
  _git_cache="/tmp/.claude-git-${_cwd_hash}"
  _git_cache_age=999
  if [ -f "$_git_cache" ]; then
    now=$(date +%s)
    _mt=$(stat -c %Y "$_git_cache" 2>/dev/null || stat -f %m "$_git_cache" 2>/dev/null || echo 0)
    case "$_mt" in ''|*[!0-9]*) _mt=0 ;; esac
    _git_cache_age=$(( now - _mt ))
  fi
  if [ "$_git_cache_age" -gt 5 ] || [ ! -f "$_git_cache" ]; then
    # Cache miss: run both git commands, write to cache
    _tmp_gc="${_git_cache}.tmp.$$"
    _gc_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo "")
    _gc_ver=$(git -C "$cwd" describe --tags --abbrev=0 2>/dev/null || echo "")
    printf '%s\n%s\n' "$_gc_branch" "$_gc_ver" > "$_tmp_gc"
    mv "$_tmp_gc" "$_git_cache" 2>/dev/null
  else
    # Cache hit: read from file with zero-fork bash builtins
    _gc_branch="" _gc_ver=""
    { read -r _gc_branch; read -r _gc_ver; } < "$_git_cache" 2>/dev/null
  fi
  # Schema fields override git-derived branch; version always from git
  [ -z "$branch" ] && branch="$_gc_branch"
  version_tag="$_gc_ver"
fi

# Sanitize newlines — single-line invariant defense for git-derived values
version_tag="${version_tag//$'\n'/ }"
branch="${branch//$'\n'/ }"

branch_full="$branch"
if [ -n "$branch" ] && [ ${#branch} -gt 12 ]; then
  branch_short="${branch:0:11}…"
else
  branch_short="$branch"
fi

version_mark=""
[ -n "$version_tag" ] && version_mark=" ${DIM}${version_tag}${RST}"

# PR number: show in workspace zone when reviewing a PR
pr_mark=""
[ "$pr_number" -gt 0 ] 2>/dev/null && pr_mark=" ${GRY}#${pr_number}${RST}"

# Vim mode indicator
vim_mark=""
case "$vim_mode" in
  NORMAL)       vim_mark=" ${GRY}[N]${RST}" ;;
  INSERT)       vim_mark=" ${GRN}[I]${RST}" ;;
  VISUAL)       vim_mark=" ${YLW}[V]${RST}" ;;
  "VISUAL LINE") vim_mark=" ${YLW}[V-L]${RST}" ;;
esac

# ── Zone 4: Duration + Rate Limits ──
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

# Lines added/removed: show as +N/-N when non-zero
lines_str=""
[ "$lines_added" -gt 0 ] 2>/dev/null && lines_str=" ${GRN}+${lines_added}${RST}"
[ "$lines_removed" -gt 0 ] 2>/dev/null && lines_str="${lines_str} ${RED}-${lines_removed}${RST}"

rate_str=""
if [ -n "$rate_5h" ]; then
  r5h_int=${rate_5h%.*}; [ -z "$r5h_int" ] && r5h_int=0
  # Guard against non-numeric values
  [ "$r5h_int" -eq "$r5h_int" ] 2>/dev/null || r5h_int=0
  if [ "$r5h_int" -gt 84 ]; then r5h_color=$RED
  elif [ "$r5h_int" -gt 59 ]; then r5h_color=$YLW
  else r5h_color=$GRN
  fi
  rate_str="${r5h_color}5h:${r5h_int}%${RST}"
fi
if [ -n "$rate_7d" ]; then
  r7d_int=${rate_7d%.*}; [ -z "$r7d_int" ] && r7d_int=0
  [ "$r7d_int" -eq "$r7d_int" ] 2>/dev/null || r7d_int=0
  if [ "$r7d_int" -gt 84 ]; then r7d_color=$RED
  elif [ "$r7d_int" -gt 59 ]; then r7d_color=$YLW
  else r7d_color=$GRN
  fi
  [ -n "$rate_str" ] && rate_str="${rate_str} "
  rate_str="${rate_str}${r7d_color}7d:${r7d_int}%${RST}"
fi

# ── Responsive assembly ──
# Pre-compute visible lengths for each zone variant to avoid
# forking visible_len inside the responsive loop (was 6-7 forks × 15 levels).
# The loop becomes pure integer arithmetic — zero forks per level.
sep="${GRY} │ ${RST}"
sep_len=3  # visible width of " │ "

# Model zone: name + marks in priority order
#   thinking type (adaptive ◉ / legacy ●) → effort level → fast mode ⚡ → remote 🌐 → agent @name
_model_full="${m_color}${BOLD}${m_full}${RST}${think_mark}${effort_mark}${fast_mark}${remote_mark}${agent_mark}"
_model_mid="${m_color}${BOLD}${m_mid}${RST}${think_mark}${effort_mark}${fast_mark}${remote_mark}${agent_mark}"
_model_short="${m_color}${BOLD}${m_short}${RST}${think_mark}${effort_mark}${fast_mark}${remote_mark}${agent_mark}"
visible_len "$_model_full"; lm_full=$_VL
visible_len "$_model_mid"; lm_mid=$_VL
visible_len "$_model_short"; lm_short=$_VL

# Context zone
visible_len "$ctx_full"; lc_full=$_VL
visible_len "$ctx_mid"; lc_mid=$_VL
visible_len "$ctx_short"; lc_short=$_VL

# Path zone
visible_len "${CYN}${path_full}${RST}"; lp_full=$_VL
visible_len "${CYN}${path_mid}${RST}"; lp_mid=$_VL
visible_len "${CYN}${path_short}${RST}"; lp_short=$_VL

# Branch zone
visible_len "${YLW}${branch_full}${RST}"; lb_full=$_VL
visible_len "${YLW}${branch_short}${RST}"; lb_short=$_VL

# Version mark (independent length, appended after branch)
visible_len "$version_mark"; lver=$_VL

# Vim mark
visible_len "$vim_mark"; lvim=$_VL

# PR mark (skip visible_len when empty — common case)
if [ -n "$pr_mark" ]; then
  visible_len "$pr_mark"; lpr=$_VL
else
  lpr=0
fi

# Zone 4 variants: duration + lines + rate limits
# Pre-compute all flag combinations so try_len is pure arithmetic (zero forks).
# Variants: full (all), dur_only (sd=1,sr=0), dur_rate (sd=1,sr=1),
#           rate_only (sd=0,sr=1), lines_only (sd=0,sr=0 but lines present)
_z4_full=""; _z4_dur_only=""; _z4_dur_rate=""; _z4_rate_only=""; _z4_lines_only=""
if [ -n "$dur_str" ]; then
  _z4_full="${GRY}${dur_str}${RST}${lines_str}"; _z4_dur_only="$_z4_full"; _z4_dur_rate="$_z4_full"
elif [ -n "$lines_str" ]; then
  _z4_full="${lines_str# }"
fi
if [ -n "$lines_str" ]; then
  _z4_lines_only="${lines_str# }"
  # Seed dur variants with lines when duration absent (sd=1 falls through to lines)
  [ -z "$dur_str" ] && { _z4_dur_only="$_z4_lines_only"; _z4_dur_rate="$_z4_lines_only"; }
fi
if [ -n "$rate_str" ]; then
  [ -n "$_z4_full" ] && _z4_full="${_z4_full} "
  _z4_full="${_z4_full}${rate_str}"
  _z4_rate_only="$rate_str"
  [ -n "$_z4_dur_rate" ] && _z4_dur_rate="${_z4_dur_rate} "
  _z4_dur_rate="${_z4_dur_rate}${rate_str}"
fi
visible_len "$_z4_full"; lz4_full=$_VL
visible_len "$_z4_dur_only"; lz4_dur_only=$_VL
visible_len "$_z4_dur_rate"; lz4_dur_rate=$_VL
visible_len "$_z4_rate_only"; lz4_rate_only=$_VL
visible_len "$_z4_lines_only"; lz4_lines_only=$_VL

# try_build: assemble the final output string (no length computation)
# try_len: compute visible length using pre-computed zone lengths (pure arithmetic)
# Both share the same parameter signature:
#   $1=model_key $2=path_key $3=branch_key $4=context_key
#   $5=show_rate $6=show_vim $7=show_dur
try_build() {
  local m p b c sr="$5" sv="$6" sd="$7"
  case "$1" in full) m="$_model_full" ;; mid) m="$_model_mid" ;; short) m="$_model_short" ;; esac
  case "$2" in full) p="$path_full" ;; mid) p="$path_mid" ;; short) p="$path_short" ;; none) p="" ;; esac
  case "$3" in full) b="$branch_full" ;; short) b="$branch_short" ;; none) b="" ;; esac
  case "$4" in full) c="$ctx_full" ;; mid) c="$ctx_mid" ;; short) c="$ctx_short" ;; esac
  local result="${m}${sep}${c}"
  if [ -n "$p" ]; then
    result="${result}${sep}${CYN}${p}${RST}"
  fi
  if [ -n "$b" ]; then
    if [ -n "$p" ]; then
      result="${result} ${YLW}${b}${RST}${version_mark}"
    else
      result="${result}${sep}${YLW}${b}${RST}${version_mark}"
    fi
  fi
  [ "$sv" = "1" ] && result="${result}${vim_mark}"
  [ -n "$pr_mark" ] && result="${result}${pr_mark}"
  # Select pre-computed Zone 4 variant (same logic as try_len)
  local zone4=""
  if [ "$sd" = "1" ] && [ "$sr" = "1" ]; then
    zone4="$_z4_dur_rate"
  elif [ "$sd" = "1" ]; then
    zone4="$_z4_dur_only"
  elif [ "$sr" = "1" ]; then
    zone4="$_z4_rate_only"
  elif [ -n "$_z4_lines_only" ]; then
    zone4="$_z4_lines_only"
  fi
  if [ -n "$zone4" ]; then
    result="${result}${sep}${zone4}"
  fi
  printf '%s' "$result"
}

try_len() {
  local lm lp lb lc lz4 sv="$6" sd="$7"
  case "$1" in full) lm=$lm_full ;; mid) lm=$lm_mid ;; short) lm=$lm_short ;; esac
  case "$2" in full) lp=$lp_full ;; mid) lp=$lp_mid ;; short) lp=$lp_short ;; none) lp=0 ;; esac
  case "$3" in full) lb=$lb_full ;; short) lb=$lb_short ;; none) lb=0 ;; esac
  case "$4" in full) lc=$lc_full ;; mid) lc=$lc_mid ;; short) lc=$lc_short ;; esac
  # Zone 4 length based on flags
  if [ "$sd" = "1" ] && [ "$5" = "1" ]; then
    lz4=$lz4_dur_rate
  elif [ "$sd" = "1" ]; then
    lz4=$lz4_dur_only
  elif [ "$5" = "1" ]; then
    lz4=$lz4_rate_only
  elif [ $lz4_lines_only -gt 0 ]; then
    lz4=$lz4_lines_only
  else
    lz4=0
  fi
  local total=$(( lm + sep_len + lc ))
  if [ $lp -gt 0 ]; then
    total=$(( total + sep_len + lp ))
  fi
  if [ $lb -gt 0 ]; then
    if [ $lp -gt 0 ]; then
      total=$(( total + 1 + lb + lver ))  # space + branch + version
    else
      total=$(( total + sep_len + lb + lver ))  # sep + branch + version (no path)
    fi
  fi
  [ "$sv" = "1" ] && total=$(( total + lvim ))
  [ $lpr -gt 0 ] && total=$(( total + lpr ))
  if [ $lz4 -gt 0 ]; then
    total=$(( total + sep_len + lz4 ))
  fi
  _TL=$total
}

# ── Progressive truncation levels ──
# Each level: try_len sets _TL; if _TL ≤ term_cols, try_build and exit
# Content truncation: path → context → model → branch (progressive)
# Optional removal: rate limits → vim → duration → path

# L0: full model + full path + full branch + bar+%+token + all optional
try_len full full full full 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build full full full full 1 1 1; exit 0
fi

# L1: full model + mid path + full branch + bar+%+token + all optional
try_len full mid full full 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build full mid full full 1 1 1; exit 0
fi

# L2: full model + mid path + full branch + %+token (bar removed)
try_len full mid full mid 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build full mid full mid 1 1 1; exit 0
fi

# L2a: full model + mid path + full branch + % only
try_len full mid full short 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build full mid full short 1 1 1; exit 0
fi

# L2b: full model + mid path + short branch + % only
try_len full mid short short 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build full mid short short 1 1 1; exit 0
fi

# L3: full model + short path + full branch + %+token
try_len full short full mid 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build full short full mid 1 1 1; exit 0
fi

# L3a: full model + short path + short branch + %+token
try_len full short short mid 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build full short short mid 1 1 1; exit 0
fi

# L4: mid model + short path + full branch + %+token
try_len mid short full mid 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build mid short full mid 1 1 1; exit 0
fi

# L5: mid model + short path + short branch + %+token
try_len mid short short mid 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build mid short short mid 1 1 1; exit 0
fi

# L6: short model + short path + short branch + %+token
try_len short short short mid 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build short short short mid 1 1 1; exit 0
fi

# L7: short model + short path + short branch + % only
try_len short short short short 1 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build short short short short 1 1 1; exit 0
fi

# ── Progressive optional element removal ──

# L8: drop rate limits
try_len short short short short 0 1 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build short short short short 0 1 1; exit 0
fi

# L9: drop rate + vim
try_len short short short short 0 0 1; if [ "$_TL" -le "$term_cols" ]; then
  try_build short short short short 0 0 1; exit 0
fi

# L10: drop duration too
try_len short short short short 0 0 0; if [ "$_TL" -le "$term_cols" ]; then
  try_build short short short short 0 0 0; exit 0
fi

# L11: drop path too (model + context % + branch only)
try_len short none short short 0 0 0; if [ "$_TL" -le "$term_cols" ]; then
  try_build short none short short 0 0 0; exit 0
fi

# Fallback: model + context % only (no path, no branch)
try_len short none none short 0 0 0; if [ "$_TL" -le "$term_cols" ]; then
  try_build short none none short 0 0 0; exit 0
fi

# Emergency: model name only
emergency="${m_color}${BOLD}${m_short}${RST}"
visible_len "$emergency"; if [ "$_VL" -le "$term_cols" ]; then
  printf '%s' "$emergency"; exit 0
fi
# Last resort: truncate by display width (not char count — handles CJK/emoji)
raw="$m_short"
visible_len "$raw"
while [ "$_VL" -gt "$term_cols" ] && [ ${#raw} -gt 1 ]; do
  raw="${raw:0:$((${#raw}-1))}"
  visible_len "$raw"
done
printf '%s' "$raw"
