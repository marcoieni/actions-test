#!/bin/bash
set -euo pipefail

# Free disk space on Linux GitHub action runners.
# Script inspired by https://github.com/jlumbroso/free-disk-space

# When updating to a new ubuntu version (e.g. from ubuntu-24.04):
# - Check that there are no docker images preinstalled with `docker image ls`
# - Check that there are no big packages preinstalled that we aren't using
# - Check that all directores we are removing are still present (look at the warnings)

# Print a line of the specified character.
printSeparationLine() {
    for ((i = 0; i < 80; i++)); do
        printf "%s" "$1"
    done
    printf "\n"
}

# Compute available space.
# REF: https://unix.stackexchange.com/a/42049/60849
# REF: https://stackoverflow.com/a/450821/408734
getAvailableSpace() {
    df -a | awk 'NR > 1 {avail+=$4} END {print avail}'
}

# Make Kb human readable (assume the input is Kb).
# REF: https://unix.stackexchange.com/a/44087/60849
formatByteCount() {
    numfmt --to=iec-i --suffix=B --padding=7 "$1"'000'
}

# Check if the architecture is x86.
isX86() {
    local arch
    arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
        return 0
    else
        return 1
    fi
}

# Execute a task, printing how much space was saved and how long it took to run the task
execAndMeasure() {
    local task_name=${1}

    local start
    start=$(date +%s)

    local before
    before=$(getAvailableSpace)

    # Run the task. Skip the first argument because it's the task name.
    "${@:2}"

    local end
    end=$(date +%s)

    local after
    after=$(getAvailableSpace)

    # How much space was saved.
    local saved=$((after - before))
    # How long the task took.
    local seconds_taken=$((end - start))

    echo "==> ${task_name}: Saved $(formatByteCount "$saved") in $seconds_taken seconds"
}

# Print output of df with caption. It shows information about disk space.
printDF() {
    local caption=${1}

    printSeparationLine "="
    echo "${caption}"
    echo ""
    echo "$ df -h"
    echo ""
    df -h
    printSeparationLine "="
    echo ""
}

removeUnusedDirsAndFiles() {
    local to_remove=(
        "/etc/mysql"
        "/usr/local/aws-sam-cli"
        "/usr/local/doc/cmake"
        "/usr/local/julia"*
        "/usr/local/lib/android"
        "/usr/local/share/chromedriver-"*
        "/usr/local/share/chromium"
        "/usr/local/share/cmake-"*
        "/usr/local/share/edge_driver"
        "/usr/local/share/gecko_driver"
        "/usr/local/share/icons"
        "/usr/local/share/vim"
        "/usr/local/share/emacs"
        "/usr/local/share/powershell"
        "/usr/local/share/vcpkg"
        "/usr/share/apache-maven-"*
        "/usr/share/gradle-"*
        "/usr/share/java"
        "/usr/share/kotlinc"
        "/usr/share/miniconda"
        "/usr/share/php"
        "/usr/share/ri"
        "/usr/share/swift"

        # binaries
        "/usr/local/bin/azcopy"
        "/usr/local/bin/bicep"
        "/usr/local/bin/ccmake"
        "/usr/local/bin/cmake-"*
        "/usr/local/bin/cmake"
        "/usr/local/bin/cpack"
        "/usr/local/bin/ctest"
        "/usr/local/bin/helm"
        "/usr/local/bin/kind"
        "/usr/local/bin/kustomize"
        "/usr/local/bin/minikube"
        "/usr/local/bin/packer"
        "/usr/local/bin/phpunit"
        "/usr/local/bin/pulumi-"*
        "/usr/local/bin/pulumi"
        "/usr/local/bin/stack"

        # Haskell runtime
        "/usr/local/.ghcup"

        # Azure
        "/opt/az"
        "/usr/share/az_"*

        # Environemnt variable set by GitHub Actions
        "$AGENT_TOOLSDIRECTORY"
    )

    local existing=()
    for element in "${to_remove[@]}"; do
        if [ ! -e "$element" ]; then
            echo "::warning::Directory or file $element does not exist, skipping."
        else
            existing+=("$element")
        fi
    done

    execAndMeasure "Removed unused directories" sudo rm -rf "${existing[@]}"
}

removeNodeModules() {
    sudo npm uninstall -g \
        "@bazel/bazelisk" \
        "grunt"           \
        "gulp"            \
        "lerna"           \
        "n"               \
        "newman"          \
        "parcel"          \
        "typescript"      \
        "webpack-cli"     \
        "webpack"         \
        "yarn"
}

# Remove unused packages.
cleanPackages() {
    local packages=(
        '.*-icon-theme$'
        '^aspnetcore-.*'
        '^dotnet-.*'
        '^java-*'
        '^libllvm.*'
        '^llvm-.*'
        '^mercurial.*'
        '^mysql-.*'
        '^vim.*'
        '^fonts-.*'
        'azure-cli'
        'buildah'
        'cpp-13'
        'firefox'
        'gcc-12'
        'gcc-13'
        'gcc-14'
        'gcc'
        'g++-14'
        'gfortran-14'
        'groff-base'
        'kubectl'
        'libgl1-mesa-dri'
        'microsoft-edge-stable'
        'php.*'
        'podman'
        'powershell'
        'skopeo'
        'snapd'
        'tmux'
    )

    if isX86; then
        packages+=(
            'google-chrome-stable'
            'google-cloud-cli'
        )
    fi

    sudo apt-get purge -y --autoremove --fix-missing "${packages[@]}"

    echo "=> apt-get autoremove"
    sudo apt-get autoremove -y || echo "::warning::The command [sudo apt-get autoremove -y] failed"
    sudo apt-get clean || echo "::warning::The command [sudo apt-get clean] failed failed"
}

# Remove Swap storage
cleanSwap() {
    sudo swapoff -a || true
    sudo rm -rf /mnt/swapfile || true
    free -h
}

removePythonPackages() {
    local packages=(
    )

    if isX86; then
        packages+=(
            'ansible-core'
        )
    fi

    for p in "${packages[@]}"; do
        sudo pipx uninstall "$p"
    done
}

main() {
    printDF "BEFORE CLEAN-UP:"

    execAndMeasure "Unused packages" cleanPackages
    if isX86; then
        # On ARM, `npm uninstall` fails with a segmentation fault.
        execAndMeasure "Node modules" removeNodeModules
    fi
    execAndMeasure "Python Packages" removePythonPackages
    removeUnusedDirsAndFiles
    execAndMeasure "Swap storage" cleanSwap

    printDF "AFTER CLEAN-UP:"
}

execAndMeasure "Total" main
