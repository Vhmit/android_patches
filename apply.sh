#!/bin/bash -xe
#
# Script to apply patches from rom_patches
# Supports multiple categories and applies all patches in each repo at once
#

# Absolute path to the script directory
MY_PATH=$(dirname "$(realpath "$0")")
TOPDIR=$(pwd)

# Use categories provided as arguments; otherwise, detect all valid categories automatically
if [ $# -gt 0 ]; then
    CATEGORIES="$@"
fi

# Remove previous failure log if it exists
rm -f patch-failed.txt || true

# Loop through categories (e.g., lineage-18.1, crdroid-10.0)
for d in $CATEGORIES; do
    # Loop through directories containing patches
    for repo_dir in $(find -L "$MY_PATH/$d" -mindepth 1 -type d | sort | uniq); do
        # Skip if no patches are found in this directory
        patch_count=$(find "$repo_dir" -maxdepth 1 -name '*.patch' | wc -l)
        [ "$patch_count" -eq 0 ] && continue

        # Relative path of the repo in the source tree
        repo_dir_rel="${repo_dir#$MY_PATH/$d/}"

        cd "$repo_dir_rel" || continue
        echo "➡ Applying patches from $d in $repo_dir_rel"

        # Apply all patches in this repo
        if ! git am "$MY_PATH/$d/$repo_dir_rel"/*.patch; then
            echo "❌ Failed to apply patches in $d $repo_dir_rel"
            git am --abort || true
            echo "$d $repo_dir_rel" >> "$TOPDIR/patch-failed.txt"
        fi

        cd "$TOPDIR"
    done
done

echo "✅ Process completed. Check patch-failed.txt for any failures."
