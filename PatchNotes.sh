#!/bin/sh
# Remove temp files on exit
trap 'rm -f "$removed_tmp" "$added_tmp"' EXIT
removed_tmp=$(mktemp)
added_tmp=$(mktemp)

filter_added_lines() {
  awk -v removed_file="$1" '
    FILENAME == removed_file {count[$0]++; next}
    {
      if (count[$0] > 0) {
        count[$0]--;
        next;
      }
      if ($0 ~ /[^[:space:]]/) {
        line = $0
        sub(/::.*$/, "", line)
        print line
      }
    }
  ' "$1" "$2"
}

FILE_TO_TRACK="7huibjgkll.txt"

echo "### Patch Notes for Last 5 Commits of $FILE_TO_TRACK ###"

# Get the last 5 commit hashes that modified the target file, newest first
commit_hashes=$(git log -n 5 --pretty=format:%H -- "$FILE_TO_TRACK" 2>/dev/null)

# Check if there are any commits to process
if [ -z "$commit_hashes" ]; then
  echo "No commits found for $FILE_TO_TRACK in the history to process."
else
  # Process each commit
  for commit_sha in $commit_hashes; do
    commit_subject=$(git log -n 1 --pretty=format:"%s" $commit_sha)
    commit_short_hash=$(git log -n 1 --pretty=format:"%h" $commit_sha)
    commit_date=$(git log -n 1 --pretty=format:"%ad" --date=format:"%Y-%m-%d %H:%M" $commit_sha)

    echo "\n--- ${commit_date} ---"

    # Get removed lines (raw content)
    git show "$commit_sha" --pretty=format: --unified=0 -- "$FILE_TO_TRACK" | grep '^-' | grep -v '^--- ' | sed -e 's/^-//' > "$removed_tmp"

    # Get added lines (raw content)
    git show "$commit_sha" --pretty=format: --unified=0 -- "$FILE_TO_TRACK" | grep '^+' | grep -v '^+++ ' | sed -e 's/^+//' > "$added_tmp"

    # Filter: Added lines NOT matched by removals, drop blanks, strip IDs
    added_lines=$(filter_added_lines "$removed_tmp" "$added_tmp")

    if [ -n "$added_lines" ]; then
      # Pipe the lines to awk for numbering
      echo "$added_lines" | awk '{print NR ": " $0}'
    else
      echo "(No relevant additions found in this commit for $FILE_TO_TRACK)"
    fi
  done
fi

echo "\n\n### Current Unstaged Added Lines for $FILE_TO_TRACK ###"

git diff --unified=0 -- "$FILE_TO_TRACK" | grep '^-' | grep -v '^--- ' | sed -e 's/^-//' > "$removed_tmp"
git diff --unified=0 -- "$FILE_TO_TRACK" | grep '^+' | grep -v '^+++ ' | sed -e 's/^+//' > "$added_tmp"
unstaged_added=$(filter_added_lines "$removed_tmp" "$added_tmp")

if [ -n "$unstaged_added" ]; then
  echo "$unstaged_added" | awk '{print NR ": " $0}'
else
  echo "(No relevant unstaged additions found for $FILE_TO_TRACK)"
fi

echo "\n### Current Staged Added Lines for $FILE_TO_TRACK ###"

git diff --cached --unified=0 -- "$FILE_TO_TRACK" | grep '^-' | grep -v '^--- ' | sed -e 's/^-//' > "$removed_tmp"
git diff --cached --unified=0 -- "$FILE_TO_TRACK" | grep '^+' | grep -v '^+++ ' | sed -e 's/^+//' > "$added_tmp"
staged_added=$(filter_added_lines "$removed_tmp" "$added_tmp")

if [ -n "$staged_added" ]; then
  echo "$staged_added" | awk '{print NR ": " $0}'
else
  echo "(No relevant staged additions found for $FILE_TO_TRACK)"
fi
