#!/usr/bin/env bash
# cepa Orca attention flag — marks this checkout's own Orca worktree unread
# with a `NEEDS YOU: <question>` comment while an operator question is open,
# and clears it after the answer (punch-list L57). `cepa:autonomy` §12b rule 7
# owns WHEN a session runs it (rule 7's **The operator** kind: mark right
# before the AskUserQuestion call, clear right after the answer); this script
# owns HOW the flag is set, cleared and proved.
#
# Why: NEEDS YOU on Orca's Agent Dashboard is built from Orca's hook events.
# On 2026-11-01 dpc-pro's coord@main had an AskUserQuestion open while the
# dashboard listed dpc-pro in no column, and `worktree ps` read its row
# `done` (L57). The unread dot and the worktree comment are stored metadata
# that no hook event moves; Orca's own CLI guide documents `--unread` as the
# way "to ask for a person's attention". This adds a second signal. It does
# not fix the dashboard.
#
# Who runs it: a coordinator or a solo session, never a dispatched worker. A
# worker never calls AskUserQuestion (rule 7, **A coordinator**), so it has
# no question to flag; its question goes to its coordinator by `ask`.
#
# Usage: orca-attention.sh  <stdin      (it takes no arguments)
#   stdin is FIELD lines only, inside the session's quoted heredoc
#   (`<<'CEPA_FIELDS'`), so no value is ever inside a quoted shell string:
#     cli: <cli>       §12a's printed `cli=` value, checked as orca-rebind.sh
#                      checks it.
#     action: <mark|clear>
#     file: <path>     mark only: the question file, checked as orca-send.sh
#                      checks its message file, but named
#                      `cepa-attention-<name>.txt`: an absolute path, a
#                      regular file this user owns (no symlink), outside this
#                      checkout and its main checkout. A path that passes is
#                      read and removed before its text is checked, so each
#                      file serves one run. The text comes from the session,
#                      so it never passes through the shell: it goes to Orca
#                      as one argv word.
#   A field line is `<name>: <value>`, each name at most once. An empty line
#   ends the fields; only empty lines may follow. Any other line is refused.
#   The question text is one line of 1 to 200 characters with no control
#   character; a leading `NEEDS YOU:` is dropped so it is not doubled.
#
# Which worktree: only this checkout's own. `worktree current --json` is run
# from `git rev-parse --show-toplevel`; its path, mapped from
# `\\wsl.localhost\<distro>\…` to `/…` only when <distro> equals
# WSL_DISTRO_NAME (orca-lane.sh's rule), must equal that top level with
# symlinks resolved, and its id must be `<repoId>::<path>`. Every `set` and
# `show` then names that worktree by its full `id:`, never `active` (the
# worktree the operator has open, not this one).
#
# What it does:
#   mark   1. `worktree set --worktree id:<id> --unread --comment
#             "NEEDS YOU: <question>" --json`.
#          2. `worktree show` by id must report that exact comment and
#             `isUnread: true`.
#   clear  1. `worktree show` by id. A comment that does not start with
#             `NEEDS YOU: ` is not this script's: nothing is changed (the
#             operator or another tool may have written it since).
#          2. `worktree set --worktree id:<id> --read --comment " " --json`.
#          3. `worktree show` by id must report comment " " and
#             `isUnread: false`.
#
# Prints one line. Exit codes:
#   0  `ORCA attention: marked — …`, `ORCA attention: cleared — …`, or
#      `ORCA attention: ok — nothing to clear …`.
#   3  `ORCA attention failed: …` — an Orca call failed, the worktree could
#      not be proved to be this checkout's, or the re-read does not show the
#      change. The question is still asked; the body says the flag failed.
#   4  `ORCA attention refused: <reason>` — a field, the file or the
#      environment failed its check. No Orca call was made.
#
# Measured on Orca 1.4.245 (WSL), 2026-11-01, on this repo's `roles` worktree
# only, by its full id (punch-list L57):
#   - `set --unread --comment "NEEDS YOU: probe L57"`: `show` then reported
#     that comment and `isUnread: true`; `workspaceStatus` was unchanged.
#   - `set --read` cleared `isUnread` and kept the comment.
#   - `set --comment x` left `isUnread` unchanged; `set --unread` alone kept
#     the comment.
#   - `set --comment ""` returned `"ok": true` and CHANGED NOTHING: the old
#     comment stayed. `--comment=` did the same. `--comment null` stored the
#     text `null`. `--comment " "` stored one space. So no CLI call restores
#     an empty comment, and clear writes one space, which shows as blank.
#   - `worktree current --json` from this worktree returned its row
#     (`result.worktree.{id, repoId, path}`, the UNC path); from /tmp it
#     returned `"ok": false`, `selector_not_found`; from the main checkout it
#     returned the main checkout's row.
#
# STATED LIMITS:
#   - It does not fix Orca's dashboard or NEEDS YOU; it adds the sidebar
#     unread dot and the worktree card comment, which no hook event changes.
#   - Mark overwrites any comment the worktree had; clear writes one space,
#     not the old comment (no CLI call restores an empty one, measured above).
#   - Two sessions in one checkout share one worktree row: the second mark
#     overwrites the first, and the first clear clears both. One live session
#     per checkout is the rule (§10).
#   - Opening the worktree in Orca may clear the unread dot (not measured);
#     the comment stays until clear.
#   - A session that ends before clear (closed tab, lost context) leaves the
#     flag set; the next session in that checkout clears it on its first
#     clear run, or the operator clears it in Orca.
#   - "This checkout" is the top level of the shell's current directory. A
#     session that cd'd into another worktree (a coordinator reading a
#     lane) and runs the block there flags that worktree: rule 7 says to run
#     it from the session's own checkout, and the result line names the path.
#   - A `set` cut by the 15-second bound may still land later on the Windows
#     side (the bound kills the WSL launcher, not necessarily orca.exe; not
#     measured). A late mark then sets a flag after clear found none; the
#     session's next first-turn clear (rule 7) removes it.
#   - Clear checks the comment and its write in two calls (show, then set),
#     with no compare-and-set in Orca: an operator edit that lands between
#     them is overwritten.
#   - Clear leaves the unread dot alone when the comment is not a NEEDS YOU
#     flag; its line then says the dot is still set.
#   - A `worktree current` or `worktree show` reply is one row. Unlike
#     `worktree list`, it carries no host scope to check (L57 reads).
#   - Worst case about 140 seconds (clear makes four calls, mark three; each
#     call is at most 2 x 17 s): run the block with a tool timeout of at least
#     3 minutes.
set -u

refuse() { echo "ORCA attention refused: $1"; exit 4; }
failed() { echo "ORCA attention failed: $1"; exit 3; }

[ $# -eq 0 ] || refuse "orca-attention.sh takes no arguments; its fields go on stdin"
unset cepa_at_f_cli cepa_at_f_action cepa_at_f_file
cepa_at_seen=" "
while IFS= read -r cepa_at_line || [ -n "$cepa_at_line" ]; do
  cepa_at_line=${cepa_at_line%$'\r'}
  [ -n "$cepa_at_line" ] || break
  [[ $cepa_at_line =~ ^([a-z]+):(\ (.*))?$ ]] || refuse "a heredoc line is not a <name>: <value> field"
  cepa_at_k=${BASH_REMATCH[1]} cepa_at_v=${BASH_REMATCH[3]}
  cepa_at_v=${cepa_at_v%"${cepa_at_v##*[![:space:]]}"}
  case "$cepa_at_k" in cli|action|file) ;; *) refuse "a field name is not cli, action or file" ;; esac
  [[ $cepa_at_seen != *" $cepa_at_k "* ]] || refuse "the $cepa_at_k field is given twice"
  cepa_at_seen+="$cepa_at_k "
  printf -v "cepa_at_f_$cepa_at_k" '%s' "$cepa_at_v"
done
{ cepa_at_rest=$(cat); } 2>/dev/null
[ -z "${cepa_at_rest//[[:space:]]/}" ] || refuse "the heredoc holds a line after its fields"

# The cli check is orca-rebind.sh's, unchanged.
[[ $cepa_at_seen == *" cli "* ]] || refuse "the cli field is missing"
cepa_at_cli=$cepa_at_f_cli
case "$cepa_at_cli" in
  ''|-*|*[!A-Za-z0-9._/-]*) refuse "the cli is not a plain command name" ;;
  /*) [ "$cepa_at_cli" = "${ORCA_CLI_COMMAND:-}" ] || refuse "a cli path must equal ORCA_CLI_COMMAND" ;;
  */*) refuse "a cli path must be absolute and equal ORCA_CLI_COMMAND" ;;
esac
case "${cepa_at_cli##*/}" in
  orca-ide|orca-dev) ;;
  orca) [ "$(uname -s 2>/dev/null)" != Linux ] || refuse "bare orca on Linux is the screen reader" ;;
  *) refuse "the cli does not name an Orca CLI" ;;
esac
cepa_at_action=${cepa_at_f_action-}
case "$cepa_at_action" in
  mark) [[ $cepa_at_seen == *" file "* ]] || refuse "mark needs a file field" ;;
  clear) [[ $cepa_at_seen != *" file "* ]] || refuse "clear takes no file field" ;;
  *) refuse "the action is not mark or clear" ;;
esac

cepa_at_top=$(git rev-parse --show-toplevel 2>/dev/null) || cepa_at_top=
[ -n "$cepa_at_top" ] || refuse "not inside a git checkout"
cepa_at_top=$(cd -P -- "$cepa_at_top" 2>/dev/null && pwd -P) || refuse "the checkout path could not be resolved"

# THE QUESTION FILE (mark only): orca-send.sh's message-file checks, with the
# cepa-attention- prefix. Read and removed before its text is checked.
cepa_at_q=
if [ "$cepa_at_action" = mark ]; then
  cepa_at_file=${cepa_at_f_file-}
  [[ $cepa_at_file =~ ^(/[A-Za-z0-9._@+-]+)*/cepa-attention-[A-Za-z0-9._@-]{1,64}\.txt$ \
     && $cepa_at_file != */./* && $cepa_at_file != */../* ]] \
    || refuse "the question file is not an absolute path to a cepa-attention-<name>.txt file"
  [ -f "$cepa_at_file" ] && [ ! -L "$cepa_at_file" ] && [ -O "$cepa_at_file" ] \
    || refuse "the question file is not a regular file this user owns"
  cepa_at_dir=$(cd -P -- "${cepa_at_file%/*}/" 2>/dev/null && pwd -P) || cepa_at_dir=
  [ -n "$cepa_at_dir" ] || refuse "the question file's directory could not be resolved"
  cepa_at_phys=${cepa_at_dir%/}/${cepa_at_file##*/}
  cepa_at_main=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || cepa_at_main=
  case "$cepa_at_main" in /*/.git) cepa_at_main=${cepa_at_main%/.git} ;; *) cepa_at_main= ;; esac
  for cepa_at_k in "$cepa_at_top" "$cepa_at_main"; do
    [ -z "$cepa_at_k" ] || [[ $cepa_at_file != "$cepa_at_k"/* && $cepa_at_phys != "$cepa_at_k"/* ]] \
      || refuse "the question file is inside the repo"
  done
  { cepa_at_q=$(cat -- "$cepa_at_file"); } 2>/dev/null
  cepa_at_read=$?
  rm -f -- "$cepa_at_file" 2>/dev/null
  [ ! -e "$cepa_at_file" ] || refuse "the question file could not be removed"
  [ "$cepa_at_read" = 0 ] || refuse "the question file could not be read"
  cepa_at_q=${cepa_at_q%$'\r'}
  [[ $cepa_at_q != *$'\n'* ]] || refuse "the question is not one line"
  [[ $cepa_at_q != *[[:cntrl:]]* ]] || refuse "the question holds a control character"
  cepa_at_q=${cepa_at_q#NEEDS YOU:}
  cepa_at_q=${cepa_at_q#"${cepa_at_q%%[![:space:]]*}"}
  cepa_at_q=${cepa_at_q%"${cepa_at_q##*[![:space:]]}"}
  [ -n "$cepa_at_q" ] || refuse "the question is empty"
  [ "${#cepa_at_q}" -le 200 ] || refuse "the question is longer than 200 characters"
fi

command -v "$cepa_at_cli" >/dev/null 2>&1 || refuse "$cepa_at_cli is not on PATH"
command -v timeout >/dev/null 2>&1 || refuse "no timeout command to bound the Orca calls"
command -v python3 >/dev/null 2>&1 || refuse "no python3 to read the Orca output"
cepa_at_tmp=$(mktemp -d 2>/dev/null) || refuse "mktemp failed"
trap 'rm -rf "$cepa_at_tmp"' EXIT

# One Orca call from the checkout's top level, bounded at 15 seconds plus a
# 2-second kill, retried once on the WSL interop error (orca-send.sh's rule).
# Every call here is a read or an idempotent set, so the retry is safe.
cepa_at_orca() {
  local out=$1 try e
  shift
  for try in 1 2; do
    (cd -- "$cepa_at_top" && timeout -k 2 15 "$cepa_at_cli" "$@") </dev/null >"$out" 2>"$cepa_at_tmp/err" && return 0
    [ "$try" = 1 ] || return 1
    { e=$(<"$cepa_at_tmp/err"); } 2>/dev/null || return 1
    [[ $e == *UtilAcceptVsock* && $e == *"accept4 failed 110"* ]] || return 1
  done
  return 1
}

# Reads a worktree reply. Mode `current` prints the id when the row is this
# checkout's (path equal to the top level, id `<repoId>::<path>`); mode `show`
# prints `<isUnread>` then the comment, for the id given. Any other shape
# exits 1, so a changed Orca reads as a failed read.
cepa_at_py() {
  python3 -I -c '
import json, os, re, sys
mode, f = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(f))
    w = d["result"]["worktree"] if d.get("ok") is True else sys.exit(1)
    i, rid, p = w["id"], w["repoId"], w["path"]
except Exception:
    sys.exit(1)
def clean(s):
    return isinstance(s, str) and s and not any(ord(c) < 32 or ord(c) == 127 for c in s)
if not (clean(i) and clean(rid) and clean(p)) or not re.fullmatch(r"[A-Za-z0-9-]{1,64}", rid):
    sys.exit(1)
if i != rid + "::" + p:
    sys.exit(1)
if mode == "current":
    top, distro = sys.argv[3], sys.argv[4]
    m = re.fullmatch(r"\\\\wsl\.localhost\\([^\\]+)\\(.*)", p)
    if m:
        if not distro or m.group(1) != distro:
            sys.exit(1)
        p = "/" + m.group(2).replace("\\", "/")
    if not p.startswith("/") or "\\" in p or any(s in (".", "..") for s in p.split("/")[1:]):
        sys.exit(1)
    if (p.rstrip("/") or "/") != top:
        sys.exit(1)
    print(i)
    sys.exit(0)
if mode == "show":
    if i != sys.argv[3]:
        sys.exit(1)
    u, c = w.get("isUnread"), w.get("comment")
    if type(u) is not bool or not isinstance(c, str):
        sys.exit(1)
    sys.stdout.write(("1" if u else "0") + "\n" + c)
    sys.exit(0)
sys.exit(1)
' "$@" 2>/dev/null
}

cepa_at_orca "$cepa_at_tmp/cur.json" worktree current --json \
  || failed "worktree current failed, so this checkout's Orca worktree is unknown; nothing was changed"
cepa_at_id=$(cepa_at_py current "$cepa_at_tmp/cur.json" "$cepa_at_top" "${WSL_DISTRO_NAME:-}") \
  || failed "worktree current did not return this checkout's own worktree ($cepa_at_top); nothing was changed"

# Prints nothing; sets cepa_at_u (0/1) and cepa_at_c (the comment).
cepa_at_show() {
  local s
  cepa_at_orca "$cepa_at_tmp/show.json" worktree show --worktree "id:$cepa_at_id" --json || return 1
  s=$(cepa_at_py show "$cepa_at_tmp/show.json" "$cepa_at_id" && printf x) || return 1
  s=${s%x}
  [ -n "$s" ] || return 1
  cepa_at_u=${s%%$'\n'*} cepa_at_c=${s#*$'\n'}
  case "$cepa_at_u" in 0|1) ;; *) return 1 ;; esac
}

if [ "$cepa_at_action" = mark ]; then
  cepa_at_want="NEEDS YOU: $cepa_at_q"
  cepa_at_orca "$cepa_at_tmp/set.json" worktree set --worktree "id:$cepa_at_id" --unread --comment "$cepa_at_want" --json \
    || failed "worktree set failed; the flag may not be set"
  cepa_at_show || failed "worktree set ran, but the re-read by id failed, so the flag is not proved"
  [ "$cepa_at_u" = 1 ] && [ "$cepa_at_c" = "$cepa_at_want" ] \
    || failed "after worktree set, the re-read does not show the unread dot and the NEEDS YOU comment"
  echo "ORCA attention: marked — $cepa_at_top is unread with comment \"$cepa_at_want\""
  exit 0
fi

cepa_at_show || failed "worktree show failed, so whether a flag is set is unknown; nothing was changed"
case "$cepa_at_c" in
  "NEEDS YOU: "*) ;;
  *) cepa_at_dot=
     [ "$cepa_at_u" = 0 ] || cepa_at_dot="; the unread dot is still set, by someone else"
     echo "ORCA attention: ok — nothing to clear (the comment is not a NEEDS YOU flag$cepa_at_dot)"; exit 0 ;;
esac
cepa_at_orca "$cepa_at_tmp/set.json" worktree set --worktree "id:$cepa_at_id" --read --comment " " --json \
  || failed "worktree set failed; the NEEDS YOU flag may still show"
cepa_at_show || failed "worktree set ran, but the re-read by id failed, so the clear is not proved"
[ "$cepa_at_u" = 0 ] && [ "$cepa_at_c" = " " ] \
  || failed "after worktree set, the re-read still shows the unread dot or a comment"
echo "ORCA attention: cleared — $cepa_at_top has no unread dot and no NEEDS YOU comment"
exit 0
