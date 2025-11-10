#!/bin/bash -e
#
# Script to apply patches from rom_patches
# Supports multiple categories and applies all patches in each repo at once
#

# Absolute path to the script directory
MY_PATH=$(dirname "$(realpath "$0")")
TOPDIR=$(pwd)

# Discover all available categories
mapfile -t ALL_CATEGORIES < <(find "$MY_PATH" -mindepth 1 -maxdepth 1 -type d -exec basename '{}' ';' | grep -v '^\.git$' | sort)

echo "Available categories:"
for i in "${!ALL_CATEGORIES[@]}"; do
    echo "$((i+1))) ${ALL_CATEGORIES[i]}"
done
echo "$(( ${#ALL_CATEGORIES[@]} + 1 ))) all"
echo
echo "Enter the numbers of the categories you want to apply, separated by space (e.g., 1 3) or $((${#ALL_CATEGORIES[@]} + 1)) for all."
echo "Type 'cancel' to exit:"

read -r -a SEL_NUMS

# Handle cancel
if [[ "${SEL_NUMS[0],,}" == "cancel" ]]; then
    echo "Selection cancelled. Exiting."
    exit 0
fi

# Convert numbers to category names
CATEGORIES=()
ALL_INDEX=$(( ${#ALL_CATEGORIES[@]} + 1 ))
if [[ " ${SEL_NUMS[@]} " =~ " $ALL_INDEX " ]]; then
    CATEGORIES=("${ALL_CATEGORIES[@]}")
else
    for num in "${SEL_NUMS[@]}"; do
        idx=$((num-1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#ALL_CATEGORIES[@]}" ]; then
            CATEGORIES+=("${ALL_CATEGORIES[$idx]}")
        else
            echo "⚠️ Warning: Invalid number '$num'. Skipping."
        fi
    done
fi

# Remove previous failure log if it exists
rm -f patch-failed.txt || true

# Loop through categories (e.g., lineage-18.1, crdroid-10.0)
for d in "${CATEGORIES[@]}"; do
    while IFS= read -r repo_dir; do
        patch_count=$(find "$repo_dir" -maxdepth 1 -name '*.patch' | wc -l)
        [ "$patch_count" -eq 0 ] && continue

        # Relative path of the repo in the source tree
        repo_dir_rel="${repo_dir#$MY_PATH/$d/}"

        cd "$repo_dir_rel" || continue
        echo "➡ Applying patches from $d in $repo_dir_rel"

        for patch_file in "$MY_PATH/$d/$repo_dir_rel"/*.patch; do
            [ -f "$patch_file" ] || continue

            # Skip if patch already applied
            if git apply --check "$patch_file" &>/dev/null; then
                # Patch can be applied
                if ! git am "$patch_file"; then
                    echo "❌ Failed to apply patch $patch_file"
                    git am --abort || true
                    echo "$d $repo_dir_rel $patch_file" >> "$TOPDIR/patch-failed.txt"
                fi
            else
                # Already applied or cannot be applied
                echo "✔ Patch already applied or cannot apply: $(basename "$patch_file")"
            fi
        done

        cd "$TOPDIR"
    done < <(find -L "$MY_PATH/$d" -mindepth 1 -type d | sort | uniq)
done

echo "✅ Process completed. Check patch-failed.txt for any failures."
