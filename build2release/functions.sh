#!/bin/bash

usage()
{
cat << EOF
Mageia official docker image new version release script.

Usage: $0 OPTIONS

This script will push (and optionally build using mkimage-dnf.sh) a new mageia
root filesystem to juanluisbaptiste/docker-brew-mageia.

OPTIONS:
-a    Architecture to build.
-b    Build image.
-B    Build directory.
-d    Checkout dist branch.
-m    Mageia version to push/build.
-M    Update message.
-p    Only prepare the dist branch for commit & push (backup rootfs files and
      recreate a clean dist branch).
-P    Commit and push new rootfs file (will call -p).
-r    Mirror to use. Mandatory when building non x86_64 archquitectures.
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
  if [ $? -eq 0 ]; then
    # Checkout dist branch to backup existing images
    git checkout dist
    if [ $? != 0 ]; then
      echo "ERROR: Cannot checkout dist branch." && exit 1
    fi
    #Check if the previous version is deprecated and if not back it up
    if [[ ${MGA_PREV_VERSION} != *"${MGA_DEPRECATED_VERSIONS}"* ]]; then
      backup_previous_versions
      prepare_branch
      restore_previous_versions
    fi
  else
    echo "ERROR: dist branch does not exist !!" && exit 1
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

function push () {
  commit_msg="${COMMIT_MSG:-Automated Image Update by ${0} v. ${VERSION}}"
  # commit_msg="Automated Image Update by ${0} v. ${VERSION}"

  dist_branch_exists="$(git branch|grep dist)"
  if [ $? -eq 0 ]; then
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
  else
    echo "ERROR: dist branch does not exist" && exit 1
  fi
}

function backup_previous_versions () {
  echo "* Backing up existing images:"
  mkdir -p ${TMP_DIR}/
  sudo cp -rp ${BUILD_DIR}/dist ${TMP_DIR}/
  [ $? -gt 0 ] && echo "ERROR: Cannot backup existing images." && exit 1
}

function restore_previous_versions () {
  if [ -d "${TMP_DIR}/dist" ]; then
    # Copy back old relase rootfs files
    echo "* Restoring images into dist branch:"
    sudo cp -rpf ${TMP_DIR}/dist ${BUILD_DIR}/
    [ $? -gt 0 ] && echo "ERROR: Cannot copy back rootfs file." && exit 1
  fi
}

function build_image() {
  echo "* Building mageia ${MGA_VERSION}  rootfs image for architecture: ${ARCH}"

  if [ "${ARCH}" != "x86_64" ]; then
    ARCH=" -a ${ARCH}"
    if [ "${MIRROR}" != "" ]; then
      MIRROR=" --mirror=${MIRROR}"
    else
      echo -e "ERROR: When building any architecture different from x86_64 wou need to set a mirror with -r parameter." && exit 1
    fi
  fi

    sudo ./mkimage.sh --rootfs="${NEW_ROOTFS_DIR}/" --version=${MGA_VERSION} ${ARCH} ${MIRROR}
    [ $? -gt 0 ] && echo "ERROR: Cannot build rootfs file." && exit 1
echo "* Done building image."
  # fi
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
  sudo rm -fr "${TMP_DIR}"
  git checkout master
  exit 1
}
