#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Jitsi stable-11146-2 which has
# already seen two releases of it (v11146-2-0 and v11146-2-1), and which also
# carries the tags of the plain stable-11146 version and its own hotfix
# lineage - the tag families this repository's real history mixes.
#
# The defaults file deliberately carries the traps this role's real one has:
# a second, similarly named version variable for something that is not the
# Jitsi version at all, and a commented-out `jitsi_version` line. Neither may
# be picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# jitsi_version: stable-9999
		jitsi_ldap_version: "3"
		jitsi_version: stable-11146-2
		jitsi_container_image_tag: "{{ jitsi_version }}"
	YAML
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	# The plain version's releases and the hotfix's releases coexist.
	git tag 'v11146-0'
	git tag 'v11146-1'
	local release_number
	for release_number in 0 1; do
		git tag "v11146-2-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_to_stable="sed -i 's|^jitsi_version: stable-11146-2|jitsi_version: stable-11500|' defaults/main.yml"
bump_to_hotfix="sed -i 's|^jitsi_version: stable-11500|jitsi_version: stable-11500-1|' defaults/main.yml"
revert_version="sed -i 's|^jitsi_version: stable-11500|jitsi_version: stable-11146-2|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v11500-0 "$(merge "$bump_to_stable")"
expect 'task edit'    v11500-1 "$(merge "$edit_task")"
expect 'template'     v11500-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v11146-2-2 "$(merge "$edit_task")"
expect 'version bump' v11500-0   "$(merge "$bump_to_stable")"

# Upstream's hotfixes carry their own version suffix. Its releases must start
# their own counter, not continue the plain version's - and the plain
# version's tags (v11500-0, v11500-1, ...) must never be mistaken for
# releases of the hotfix.
scenario 'A hotfix bump opens its own tag family'
expect 'stable bump'  v11500-0   "$(merge "$bump_to_stable")"
expect 'task edit'    v11500-1   "$(merge "$edit_task")"
expect 'hotfix bump'  v11500-1-0 "$(merge "$bump_to_hotfix")"
expect 'task edit'    v11500-1-1 "$(merge "$edit_task")"

# The mirror direction: the hotfix's tags must not inflate the plain
# version's counter. With v11146-2-0/-1 already in history, a plain
# stable-11146 checkout would be at release counter 1 (v11146-0/-1 exist),
# not at anything derived from the hotfix family.
scenario 'Hotfix tags do not count against the plain version'
sed -i 's|^jitsi_version: stable-11146-2|jitsi_version: stable-11146|' defaults/main.yml
git add -A && git commit -qm 'Downgrade to the plain version'
expect 'a task' v11146-2 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''           "$(merge "$edit_readme")"
expect 'a script' ''           "$(merge "$edit_script")"
expect 'a task'   v11146-2-2   "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v11146-2-$release_number"
done
expect 'a task' v11146-2-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_to_stable" > /dev/null
# The role is now identical to what v11146-2-1 already published, so there is
# nothing new to release.
expect 'a revert' ''           "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_to_stable" > /dev/null
expect 'a revert' v11146-2-2   "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
