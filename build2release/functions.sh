#!/bin/bash

# Archquitectures to build for each supported versions
declare -A MGA_SUPPORTED_ARCHS
MGA_SUPPORTED_ARCHS[7]="x86_64 aarch64 armv7hl"
MGA_SUPPORTED_ARCHS[8]="x86_64 aarch64 armv7hl"
MGA_SUPPORTED_ARCHS[cauldron]="x86_64 aarch64 armv7hl"
# Version tags of supported versions
declare -A MGA_SUPPORTED_VERSION_TAGS
MGA_SUPPORTED_VERSION_TAGS[7]="7"
MGA_SUPPORTED_VERSION_TAGS[8]="8,latest"
MGA_SUPPORTED_VERSION_TAGS[cauldron]="cauldron"

# Default mirror to use for all builds
MIRROR="http://distrib-coffee.ipsl.jussieu.fr/pub/linux/Mageia/distrib/"
MGA_BREW_REPO="juanluisbaptiste/docker-brew-mageia"
MGA_BREW_REPO_URL="git@github.com:${MGA_BREW_REPO}"
OFFICIAL_IMAGES_FORK="juanluisbaptiste/official-images"
OFFICIAL_IMAGES_FORK_URL="git@github.com:${OFFICIAL_IMAGES_FORK}"
OFFICIAL_IMAGES_REPO="docker-library/official-images"
OFFICIAL_IMAGES_REPO_URL="git@github.com:${OFFICIAL_IMAGES_REPO}"
# DATE=$(date +%m-%d-%Y_%H%M%S)
BUILD_LOG_FILE="${PWD}/mga-build.out"

usage()
{
cat << EOF
Mageia official docker image new version release script.

Usage: $0 OPTIONS

This script will push (and optionally build using mkimage-dnf.sh) a new mageia
root filesystem to juanluisbaptiste/docker-brew-mageia.

OPTIONS:
-b    Build image.
-B    Build directory.
-p    Commit and push new images.
-P    Create Pull Request on docker library repository (needs -U).
-r    Mirror to use.
-U    Update mageia docker library file on own fork.
-v    Verbose mode.
-V    Debug mode.
-h    Print help.
EOF
}

function print_version() {
  echo -e "Version: ${VERSION}\n"
}

function print_msg() {
  local msg=${1}

  if [[ ${VERBOSE} -eq 1 ]] || [[ ${DEBUG} -eq 1 ]]; then
    echo "${msg}"
  # else
    # echo "${msg}" | tee -a ${BUILD_LOG_FILE}
  fi
  echo "${msg}"  >> ${BUILD_LOG_FILE}
}

function run_command() {
  local command=( "$@" )

  if [[ ${DEBUG} -eq 1 ]]; then
    eval "${command[@]}"
  elif [[ ${SILENT} -eq 0 ]] && [[ ${VERBOSE} -eq 1 ]]; then
    # out=$(eval "${command[@]}" ${DEBUG_OUTPUT})
    eval "${command[@]}" | tee -a ${BUILD_LOG_FILE}
  else
    eval "${command[@]}" >> ${BUILD_LOG_FILE} 2>&1
    if [[ $? -gt 0 ]]; then
      # print_msg "${out}"
      print_msg "ERROR: Cannot run command: " "${command[@]}"
      exit 1
    fi
  fi
}


function push () {
  local commit_msg="Automated Image Update by ${PROGRAM_NAME} v${VERSION}"

  print_msg "* Preparing for commit and push new images..."
  # Add and commit the updated file
  print_msg " [-] Adding rootfs files to dist branch..."
  xz_files=$(find ${BUILD_DIR} -name '*.tar.xz')
  #gz_files=$(find . -name '*.tar.gz')

  [ "${xz_files}" != "" ] && run_command git add ${xz_files}
  #[ "${gz_files}" != "" ] && git add ${gz_files}

  print_msg " [-] Commit new rootfs file to dist branch..."
  run_command git commit -m \"${commit_msg}\"

  # Force push new dist branch
  print_msg " [-] Force-pushing new dist branch..."
  run_command git push -f origin dist
  [ $? -gt 0 ] && echo "ERROR: Cannot force-push dist branch." && exit 1
}

function build_image() {

  cd ${BUILD_DIR}/build
  print_msg "* Cloning ${MGA_BREW_REPO_URL}"
  run_command git clone ${MGA_BREW_REPO_URL}
  repo_dir=$(echo ${MGA_BREW_REPO_URL}|cut -d'/' -f2)
  cd ${repo_dir}

  print_msg "* Fetching dist branch..."
  run_command git fetch origin dist:dist ${GIT_OUTPUT}

  print_msg "* Deleting dist branch..."
  run_command git branch -D dist ${GIT_OUTPUT}

  print_msg "* Recreating dist branch..."
  run_command git checkout ${GIT_OUTPUT} -b dist master

  # Build all archs for all versions declared on MGA_SUPPORTED_ARCHS
  for mga_version in "${!MGA_SUPPORTED_ARCHS[@]}"; do
    for build_arch in ${MGA_SUPPORTED_ARCHS[${mga_version}]}; do
      print_msg "* Building mageia ${mga_version}  rootfs image for architecture: ${build_arch}"
      build_mirror=${MIRROR}/${mga_version}/${build_arch}
      new_rootfs_dir="${BUILD_DIR}/build/${repo_dir}/dist/${mga_version}/${build_arch}"
      mkdir -p ${new_rootfs_dir}
      run_command ./mkimage.sh --rootfs="${new_rootfs_dir}/" --version=${mga_version} --forcearch=${build_arch} --mirror=${build_mirror}
    done
  done
}

function update_library() {
  local commit_msg="Updated mageia images"

  # Now clone docker official-images repo and update the library build image
  print_msg "* Cloning ${OFFICIAL_IMAGES_FORK_URL}"
  cd ${BUILD_DIR}/build
  run_command git clone ${OFFICIAL_IMAGES_FORK_URL}
  repo_dir=$(echo ${OFFICIAL_IMAGES_FORK}|cut -d'/' -f2)
  cd ${repo_dir}

  # Update fork with latest remote changes before working on it
  print_msg "[+] Updating ${OFFICIAL_IMAGES_FORK} fork with latest upstream changes"
  run_command git remote add upstream ${OFFICIAL_IMAGES_REPO_URL}
  run_command git fetch upstream
  run_command git pull upstream master --rebase

  # Get the last commit hash of dist branch
  print_msg "[+] Get last commit from ${MGA_BREW_REPO}"
  git_commit=$(git ls-remote ${MGA_BREW_REPO_URL} refs/heads/dist | cut -f 1)
  [ $? -gt 0 ] && echo "ERROR: Cannot get last commit from dist branch." && exit 1
  print_msg "[+] Last commit is: ${git_commit}"
  # Update library file with new hash
  print_msg "[+] Updating library file with new commit"
  if [ "${git_commit}" != "" ]; then
    sed -i -r "s/(GitCommit: *).*/\1${git_commit}/" library/mageia
    [ $? -gt 0 ] && echo "ERROR: Cannot update commit hash on library file." && exit 1
  else
    echo "ERROR: Git commit is empty !!" && exit 1
  fi

  # Update image tags for all versions declared on MGA_SUPPORTED_VERSION_TAGS
  for mga_version in "${!MGA_SUPPORTED_VERSION_TAGS[@]}"; do
    version_tags="${MGA_SUPPORTED_VERSION_TAGS[${mga_version}]}"
    print_msg "* Updating tags for image version ${mga_version}: ${version_tags}"
    if [ "${version_tags}" != "" ]; then
      sed -i -r "s/(Tags: ${mga_version},*).*/Tags: ${version_tags}/" library/mageia
      [ $? -gt 0 ] && echo "ERROR: Cannot update tags for image version ${mga_version} on library file." && exit 1
    fi
  done

  # Add and commit change
  run_command git add library/mageia
  [ $? -gt 0 ] && echo "ERROR: Cannot git add modified library file." && exit 1
  run_command git commit -m \"${commit_msg}\"
  [ $? -gt 0 ] && echo "ERROR: Cannot commit on library file." && exit 1
  print_msg "[+] Pushing changes"
  run_command git push
  [ $? -gt 0 ] && echo "ERROR: Cannot push on library file." && exit 1

  # Create pull request on official docker library
  if [[ ${PULL_REQUEST} -eq 1 ]]; then
    print_msg "[+] Creating Pull Request on ${OFFICIAL_IMAGES_REPO} for new images..."
    run_command hub pull-request -b ${OFFICIAL_IMAGES_REPO}:master -h ${OFFICIAL_IMAGES_FORK}:master -m "${commit_msg}" -r "@yosifkit,@tianon"
    [ $? -gt 0 ] && echo "ERROR: Cannot create Pull Request." && exit 1
  fi
}

# create_pr() {
#   run_command git push -u origin "$1"
#   run_command hub pull-request -h "$1" -F -
# }

function term_handler(){
  echo "***** Build cancelled by user *****" &> /dev/tty
  rm -fr "${BUILD_DIR}"
  exit 1
}
