#!/usr/bin/env bash
# Whether this push or pull request changed files a workflow checks.
#
#   changed.sh <include-regex> [exclude-regex]
#
# Writes changed=true or changed=false to $GITHUB_OUTPUT. The workflows always
# start, so their required checks always report, and skip their steps on
# changed=false. When the changes can't be worked out (a new branch, history
# that can't be fetched) it says true: running the checks is the safe side.
set -euo pipefail

include=$1
exclude=${2:-'^$'}

base=
if [ "$GITHUB_EVENT_NAME" = pull_request ]; then
	# the checkout is the PR merged into its base; the first parent is the base
	base=HEAD^1
elif [[ ${BEFORE:-} =~ ^[0-9a-f]{40}$ && ! $BEFORE =~ ^0+$ ]] &&
	git fetch --quiet --no-tags --depth=1 origin "$BEFORE"; then
	base=$BEFORE
fi

if [ -z "$base" ] || ! files=$(git diff --name-only "$base" HEAD); then
	echo "Couldn't tell what changed, so the checks run."
	echo changed=true >>"$GITHUB_OUTPUT"
	exit 0
fi

matched=$(grep -E "$include" <<<"$files" | grep -vE "$exclude" || true)
if [ -n "$matched" ]; then
	echo "Changed, so the checks run:"
	echo "$matched" | sed 's/^/  /'
	echo changed=true >>"$GITHUB_OUTPUT"
else
	echo "Nothing this workflow checks changed, so its steps are skipped."
	echo changed=false >>"$GITHUB_OUTPUT"
fi
