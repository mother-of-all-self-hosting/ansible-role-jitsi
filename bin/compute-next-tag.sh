#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<Jitsi version without the stable- prefix>-<release>`:
#
# - if defaults/main.yml points at a Jitsi version that has never been
#   released, the release counter restarts at 0 (`v11146-2-0` for
#   `stable-11146-2`, `v11500-0` for `stable-11500`)
# - otherwise the counter is incremented, but only if something that actually
#   affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
#
# Upstream hotfix versions carry their own suffix (`stable-11146-2`), so a
# hotfix's tags (`v11146-2-0`, `v11146-2-1`, ...) live alongside the plain
# version's tags (`v11146-0`, `v11146-1`, ...). The two families never get
# counted against each other: the release counter only accepts a purely
# numeric remainder after its own version's prefix.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `jitsi_version:` so that neither `jitsi_ldap_version:` nor a
# commented-out line can be mistaken for it.
version="$(sed -nE 's|^jitsi_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the Jitsi version from $defaults_path"
	exit 1
fi

# The version values carry a `stable-` prefix (e.g. `stable-11146-2`),
# which the tags historically drop (`v11146-2-0`).
tag_prefix="v${version#stable-}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
