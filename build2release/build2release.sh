#!/bin/bash

# NOT VERY WELL TESTED !! USE IT UNDER YOUR OWN RISK !!

# From an issue in docker-brew-mageia issue:
# @tianon:
# git checkout -b dist master - this is actually how I prefer to maintain my
# images now (after trying a variety of methods); essentially, you have a "master"
# branch where you never ever commit tarballs, and it holds the full history of
# all your nice scripts and scaffolding (directories and the like), and once you're
# ready to commit and push a new tarball, you create a new "dist" branch based on
# the "master" branch, and make your single tarball commit there, then force push
# that to GitHub - once it's time for the next release, you git branch -D dist
# (to delete your local "dist" branch), and then git checkout -b dist master again
# to make a brand new one that doesn't contain that older tarball commit

# This script version
VERSION=0.2
# Set default version
MGA_LATEST_VERSION="6"
MGA_VERSION=${MGA_LATEST_VERSION}
MGA_PREV_VERSION=$((MGA_VERSION-1))
MGA_DEPRECATED_VERSIONS="3 4"
OFFICIAL_IMAGES_REPO="juanluisbaptiste/official-images"
OFFICIAL_IMAGES_REPO_URL="git@github.com:${OFFICIAL_IMAGES_REPO}"
TMP_DIR="/tmp/mga-tmp"
ROOTFS_FILE_NAME="rootfs.tar.xz"
BUILD=0
PREPARE=0
PUSH=0
UPDATE_OFFICIAL=0

# Include functions
. ./functions.sh


trap 'term_handler' INT

while getopts bm:M:pPUvh option
do
  case "${option}"
  in
    b) BUILD=1
       ;;
    m) MGA_VERSION=${OPTARG}
       ;;
    M) COMMIT_MSG=${OPTARG}
       ;;
    p) PREPARE=1
       ;;
    P) PUSH=1
       ;;
    U) UPDATE_OFFICIAL=1
       ;;
    h) usage
       exit
       ;;
    v) print_version
       exit
       ;;
    ?) usage
       exit
       ;;
  esac
done

if [[ ${MGA_VERSION} == *"${MGA_DEPRECATED_VERSIONS}"* ]]; then
  echo "ERROR: Version to build is deprecated." && exit 1
fi

NEW_ROOTFS_DIR="$(pwd)/${MGA_VERSION}/"
PREV_ROOTFS_DIR="$(pwd)/${MGA_PREV_VERSION}/"

# Checkout dist branch to get the rootfs file from older releases
echo "* Checking out dist branch:"
git fetch
[ $? -gt 0 ] && echo "ERROR: Cannot fetch remote branches." && exit 1
git checkout dist
[ $? -gt 0 ] && echo "ERROR: Cannot checkout dist branch." && exit 1

if [ ${BUILD} -eq 1 ]; then
  # First delete any old build
  rm -fr ${MGA_VERSION:?}/${ROOTFS_FILE_NAME}
  build_image
fi

if [ ${PREPARE} -eq 1 ]; then
  prepare
fi

if [ ${PUSH} -eq 1 ]; then
  push
  # Checkout back master and locally delete dist branch
  #git checkout master
  #git branch -D dist
fi

if [ ${UPDATE_OFFICIAL} -eq 1 ]; then
  update_library
fi

# Cleanup
rm -fr ${TMP_DIR}

echo "* Done."
