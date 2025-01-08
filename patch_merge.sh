#!/bin/bash

# Define the AOSP tag and target branch
AOSP_TAG="android-15.0.0_r10"
TARGET_BRANCH="15"
REMOTE_NAME="origin"

# Base URL for Project-Flare and AOSP repositories
FLARE_BASE_URL="https://github.com/Project-Flare"
AOSP_BASE_URL="https://android.googlesource.com/platform"

# List of repositories and their paths in AOSP
declare -A REPOS
REPOS=(
    ["art"]="art"
    ["bionic"]="bionic"
    ["kernel_configs"]="kernel/configs"
    ["manifest"]="manifest"
    ["bootable_deprecated-ota"]="bootable/deprecated-ota"
    ["bootable_recovery"]="bootable/recovery"
    ["build_make"]="build/make"
    ["build_soong"]="build/soong"
    ["build_release"]="build/release"
    ["external_avb"]="external/avb"
    ["external_dtc"]="external/dtc"
    ["external_e2fsprogs"]="external/e2fsprogs"
    ["external_gptfdisk"]="external/gptfdisk"
    ["external_mksh"]="external/mksh"
    ["external_tinycompress"]="external/tinycompress"
    ["external_wpa_supplicant_8"]="external/wpa_supplicant_8"
    ["external_zstd"]="external/zstd"
    ["frameworks_av"]="frameworks/av"
    ["frameworks_base"]="frameworks/base"
    ["frameworks_native"]="frameworks/native"
    ["frameworks_opt_telephony"]="frameworks/opt/telephony"
    ["hardware_interfaces"]="hardware/interfaces"
    ["hardware_google_pixel"]="hardware/google/pixel"
    ["hardware_google_pixel-sepolicy"]="hardware/google/pixel-sepolicy"
    ["hardware_libhardware"]="hardware/libhardware"
    ["hardware_ril"]="hardware/ril"
    ["packages_apps_Settings"]="packages/apps/Settings"
    ["packages_modules_Bluetooth"]="packages/modules/Bluetooth"
    ["packages_modules_Connectivity"]="packages/modules/Connectivity"
    ["packages_modules_Wifi"]="packages/modules/Wifi"
    ["packages_services_Telecomm"]="packages/services/Telecomm"
    ["system_bpf"]="system/bpf"
    ["system_core"]="system/core"
    ["system_extras"]="system/extras"
    ["system_media"]="system/media"
    ["system_security"]="system/security"
    ["system_sepolicy"]="system/sepolicy"
    ["system_update_engine"]="system/update_engine"
    ["system_vold"]="system/vold"
)

# List to keep track of repositories with merge conflicts
MERGE_CONFLICT_REPOS=()

# Function to process a repository
process_repo() {
    local repo_path=$1
    local repo_aosp_path=$2
    local repo_flare_path=${repo_path//\//_}  # Replace / with _ for Flare repositories

    echo "Processing repository: $repo_flare_path"

    # Clone the repository if it doesn't exist
    if [ ! -d "$repo_flare_path" ]; then
        echo "Cloning $repo_flare_path..."
        git clone "$FLARE_BASE_URL/$repo_flare_path.git" "$repo_flare_path" || { echo "Failed to clone $repo_flare_path"; return 1; }
    fi

    cd "$repo_flare_path" || { echo "Failed to enter directory: $repo_flare_path"; return 1; }

    # Check out the target branch
    echo "Checking out branch: $TARGET_BRANCH"
    git checkout "$TARGET_BRANCH" || git checkout -b "$TARGET_BRANCH" "$REMOTE_NAME/$TARGET_BRANCH" || { echo "Failed to checkout $TARGET_BRANCH"; cd -; return 1; }

    # Fetch updates from AOSP
    echo "Fetching updates from AOSP..."
    if ! git fetch "$AOSP_BASE_URL/$repo_aosp_path" "$AOSP_TAG"; then
        echo "Failed to fetch from AOSP for $repo_flare_path. Skipping repository."
        MERGE_CONFLICT_REPOS+=("$repo_flare_path")
        cd -
        return 0
    fi

    # Merge AOSP updates
    echo "Merging AOSP updates..."
    if ! git merge FETCH_HEAD; then
        echo "Merge conflict detected in $repo_flare_path. Skipping repository."
        MERGE_CONFLICT_REPOS+=("$repo_flare_path")
        git merge --abort  # Abort the merge to clean up
        cd -
        return 0
    fi

    # Automatically save and exit the commit message
    echo "Automatically saving the merge commit..."
    git commit --no-edit || echo "No commit needed; merge might have been fast-forward."

    # Push changes to Flare repository
    echo "Pushing changes to Flare repository..."
    if ! git push -f "$REMOTE_NAME" "$TARGET_BRANCH"; then
        echo "Failed to push changes for $repo_flare_path. Skipping repository."
        MERGE_CONFLICT_REPOS+=("$repo_flare_path")
        cd -
        return 0
    fi

    echo "Repository $repo_flare_path processed successfully."
    cd -
}

# Process each repository
for repo_path in "${!REPOS[@]}"; do
    repo_aosp_path=${REPOS["$repo_path"]}
    process_repo "$repo_path" "$repo_aosp_path" || {
        echo "Error processing $repo_path. Skipping to the next repository.";
    }
done

# Display repositories with merge conflicts
if [ ${#MERGE_CONFLICT_REPOS[@]} -ne 0 ]; then
    echo "Repositories with merge conflicts:"
    for repo in "${MERGE_CONFLICT_REPOS[@]}"; do
        echo "- $repo"
    done
else
    echo "No merge conflicts encountered."
fi

echo "Script completed."
