#!/bin/sh

FILE_TO_TRACK="7huibjgkll.txt"

echo "### Patch Notes for Last 3 Commits of $FILE_TO_TRACK ###"

# Get the last 3 commit hashes that modified the target file, oldest first for chronological order
commit_hashes=$(git log -n 3 --pretty=format:%H --reverse -- "$FILE_TO_TRACK" 2>/dev/null)

# Check if there are any commits to process
if [ -z "$commit_hashes" ]; then
  echo "No commits found for $FILE_TO_TRACK in the history to process."
else
  # Process each commit
  for commit_sha in $commit_hashes; do
    commit_subject=$(git log -n 1 --pretty=format:"%s" $commit_sha)
    commit_short_hash=$(git log -n 1 --pretty=format:"%h" $commit_sha)
    commit_date=$(git log -n 1 --pretty=format:"%ad" --date=format:"%Y-%m-%d %H:%M" $commit_sha)

    echo "\n--- Commit ${commit_short_hash}: ${commit_subject} (${commit_date}) ---"

    # Get added lines, remove '+', remove '::.*', and add line numbers for this commit
    # Only for the specific file
    added_lines=$(git show "$commit_sha" --pretty=format: --unified=0 -- "$FILE_TO_TRACK" | grep '^+[^+]' | sed -e 's/^+//' -e 's/::.*//')

    if [ -n "$added_lines" ]; then
      # Pipe the lines to awk for numbering
      echo "$added_lines" | awk '{print NR ": " $0}'
    else
      echo "(No relevant additions found in this commit for $FILE_TO_TRACK)"
    fi
  done
fi

echo "\n\n### Current Staged/Uncommitted Added Lines for $FILE_TO_TRACK ###"

# Run the original command logic for current changes (staged or unstaged)
# Only for the specific file
current_added_lines=$(git diff --unified=0 -- "$FILE_TO_TRACK" | grep '^+[^+]' | sed -e 's/^+//' -e 's/::.*//') # Check unstaged
if [ -z "$current_added_lines" ]; then
    current_added_lines=$(git diff --cached --unified=0 -- "$FILE_TO_TRACK" | grep '^+[^+]' | sed -e 's/^+//' -e 's/::.*//') # Check staged
fi

if [ -n "$current_added_lines" ]; then
  echo "$current_added_lines" | awk '{print NR ": " $0}'
else
  echo "(No relevant current additions found for $FILE_TO_TRACK in staging or working directory)"
fi
