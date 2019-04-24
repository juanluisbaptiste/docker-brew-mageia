#!/bin/bash

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
-d    Checkout dist branch.
-m    Mageia version to push/build.
-M    Update message.
-p    Only prepare the dist branch for commit & push (backup rootfs files and
      recreate a clean dist branch).
-P    Commit and push new rootfs file (will call -p).
-U    Update mageia docker library file on own fork.
-v    Print version.
-h    Print help.
EOF
}

function print_version() {
  echo -e "Version: ${VERSION}\n"
}

function prepare() {
  # First check if dist branch exists and is checkd out to avoid pushing to
  # the wrong branch
  dist_branch_exists="$(git branch|grep dist)"
  if [ "${dist_branch_exists}" == "* dist" ]; then
    #Check if the previous version is deprecated and if not back it up
    if [[ ${MGA_PREV_VERSION} != *"${MGA_DEPRECATED_VERSIONS}"* ]]; then
      backup_previous_version
    fi
    if [[ ${MGA_VERSION} -lt ${MGA_LATEST_VERSION} ]]; then
    #if [ ${MGA_VERSION} -ge 6 ]; then
      NEXT_ROOTFS_DIR="$(pwd)/${MGA_LATEST_VERSION}/"
      backup_next_version
    fi
    backup_new_version

    echo "* Delete local dist branch:"
    # Delete it locally and recreate it so it only has a single commit
    git checkout master
    git branch -D dist
    [ $? -gt 0 ] && echo "ERROR: Cannot delete local dist branch." && exit 1

    echo "* Checking out new empty dist branch:"
    # Checkout new dist branch based on master and commit image on that branch.
    git checkout -b dist master
    [ $? -gt 0 ] && echo "ERROR: Cannot create dist branch." && exit 1

    restore_previous_version
    restore_new_version
  else
    echo "ERROR: dist branch does not exist !!" && exit 1
  fi
}

function push () {
  commit_msg="${COMMIT_MSG:-Automated Image Update by ${0} v. ${VERSION}}"
  # commit_msg="Automated Image Update by ${0} v. ${VERSION}"

  dist_branch_exists="$(git branch|grep dist)"
  if [ "${dist_branch_exists}" == "* dist" ]; then
    # Prepare the branch first for commit & push
    prepare

    # Add and commit the updated file
    echo "* Adding rootfs files to dist branch:"
    xz_files=$(find . -name '*.tar.xz')
    #gz_files=$(find . -name '*.tar.gz')

    [ "${xz_files}" != "" ] && git add ${xz_files}
    #[ "${gz_files}" != "" ] && git add ${gz_files}

    echo "* Commit new rootfs file to dist branch:"
    git commit -m "${commit_msg}"
    #git commit -m "Updated image to fix issue #7."

    # Force push new dist branch
    echo "* Force-pushing new dist branch:"
    git push -f origin dist
    #git push -f origin
    [ $? -gt 0 ] && echo "ERROR: Cannot force-push dist branch." && exit 1
  fi
}
function backup_rootfs () {
  # Check if there's a rootfs tarball for a previous mageia version and move it
  # away before deleting the dist branch

  rootfs_file_path="${1}"
  rootfs_file=$(basename "${rootfs_file_path}")
  version="${2}"
  ls ${rootfs_file_path} > /dev/null 2>&1
  # ls ${MGA_PREV_VERSION}/${ROOTFS_FILE_NAME} > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "* Moving rootfs file ${rootfs_file} release away:"
    mkdir -p ${TMP_DIR}
    sudo cp ${rootfs_file_path} ${TMP_DIR}/${rootfs_file}-${version}
    [ $? -gt 0 ] && echo "ERROR: Cannot copy rootfs file: ${rootfs_file}" && exit 1
  fi
}

function backup_previous_version () {
  backup_rootfs "${PREV_ROOTFS_DIR}/${ROOTFS_FILE_NAME}" ${MGA_PREV_VERSION}
}

function backup_new_version () {
  backup_rootfs "${NEW_ROOTFS_DIR}/${ROOTFS_FILE_NAME}" ${MGA_VERSION}
}

function backup_next_version () {
  backup_rootfs "${NEXT_ROOTFS_DIR}/${ROOTFS_FILE_NAME}" ${MGA_VERSION}
}

function restore_previous_version () {
  restore_rootfs ${MGA_PREV_VERSION} "${ROOTFS_FILE_NAME}"
}

function restore_new_version () {
  restore_rootfs ${MGA_VERSION}
}

function restore_rootfs () {
  #restore_file="${1}"
  version="${1}"
  rootfs_file="${2:-$ROOTFS_FILE_NAME}"

  if [ -f "${TMP_DIR}/${rootfs_file}-${version}" ]; then
    # Copy back old relase rootfs files
    echo "* Moving back ${ROOTFS_FILE_NAME} into dist branch:"
    sudo cp ${TMP_DIR}/${rootfs_file}-${version} "$(pwd)/${version}/${rootfs_file}"
    [ $? -gt 0 ] && echo "ERROR: Cannot copy back rootfs file." && exit 1
  fi
}

function prepare_branch () {
  echo "* Delete local dist branch:"
  # Delete it locally and recreate it so it only has a single commit
  git checkout master
  git branch -D dist
  [ $? -gt 0 ] && echo "ERROR: Cannot delete local dist branch." && exit 1

  echo "* Checking out new empty dist branch:"
  # Checkout new dist branch based on master and commit image on that branch.
  git checkout -b dist master
  [ $? -gt 0 ] && echo "ERROR: Cannot create dist branch." && exit 1

}

function build_image() {
  echo "* Building mageia ${MGA_VERSION}  rootfs image:"
  # Create new rootfs file
  if [ ${MGA_VERSION} -lt 6 ]; then
    sudo ./mkimage-urpmi.sh --rootfs="${NEW_ROOTFS_DIR}/" --version=${MGA_VERSION}
    [ $? -gt 0 ] && echo "ERROR: Cannot build rootfs file." && exit 1
  else
    sudo ./mkimage.sh --rootfs="${NEW_ROOTFS_DIR}/" --version=${MGA_VERSION}
    [ $? -gt 0 ] && echo "ERROR: Cannot build rootfs file." && exit 1
echo "* Done building image."
  fi
}

function update_library() {
  # Now clone docker official-images repo and update the library build image
  echo "* Cloning ${OFFICIAL_IMAGES_REPO_URL}"
  cd ${TMP_DIR}
  git clone ${OFFICIAL_IMAGES_REPO_URL}
  repo_dir=$(echo ${OFFICIAL_IMAGES_REPO}|cut -d'/' -f2)
  cd ${repo_dir}

  # Get the last commit hash of dist branch
  git_commit=$(git ls-remote ${MGA_BREW_REPO} refs/heads/dist | cut -f 1)
  [ $? -gt 0 ] && echo "ERROR: Cannot get last commit from dist branch." && exit 1

  # Update library file with new hash
  if [ "${git_commit}" != "" ]; then
    sed -i -r "s/(GitCommit: *).*/\1${git_commit}/" library/mageia
    [ $? -gt 0 ] && echo "ERROR: Cannot update commit hash on library file." && exit 1
  else
    echo "ERROR: Git commit is empty !!" && exit 1
  fi

  # Add and commit change
  git add library/mageia
  [ $? -gt 0 ] && echo "ERROR: Cannot git add modified library file." && exit 1
  git commit -m "${commit_msg}"
  [ $? -gt 0 ] && echo "ERROR: Cannot commit on library file." && exit 1
  git push
  [ $? -gt 0 ] && echo "ERROR: Cannot push on library file." && exit 1
}

create_pr() {
  git push -u origin "$1"
  hub pull-request -h "$1" -F -
}

function term_handler(){
  echo "***** Build cancelled by user *****"
  sudo rm -fr "${NEW_ROOTFS_DIR}"
  exit 1
}
