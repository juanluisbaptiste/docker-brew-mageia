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
MGA_BREW_REPO="git@github.com:juanluisbaptiste/docker-brew-mageia"
OFFICIAL_IMAGES_REPO="juanluisbaptiste/official-images"
OFFICIAL_IMAGES_REPO_URL="git@github.com:${OFFICIAL_IMAGES_REPO}"
TMP_DIR="$(mktemp -d)"
ROOTFS_FILE_NAME="rootfs.tar.xz"
BUILD=0
PREPARE=0
PUSH=0
CHECKOUT_DIST=0
UPDATE_OFFICIAL=0
VERBOSE=0
ARCH="x86_64"
BUILD_DIR="$(pwd)"

# Include functions
. ./functions.sh


trap 'term_handler' INT

while getopts a:bB:dm:M:pPr:UvVh option
do
  case "${option}"
  in
    a) ARCH=${OPTARG}
       ;;
    b) BUILD=1
       ;;
    B) BUILD_DIR=${OPTARG}
       ;;
    d) CHECKOUT_DIST=1
       ;;
    m) MGA_VERSION=${OPTARG}
       ;;
    M) COMMIT_MSG=${OPTARG}
       ;;
    p) PREPARE=1
       ;;
    P) PUSH=1
       ;;
    r) MIRROR=${OPTARG}
      ;;
    U) UPDATE_OFFICIAL=1
       ;;
    h) usage
       exit
       ;;
    v) print_version
       exit
       ;;
    V) VERBOSE=1
       ;;
    ?) usage
       exit
       ;;
  esac
done

[ ${VERBOSE} -eq 1 ] && set -x

if [[ ${MGA_VERSION} == *"${MGA_DEPRECATED_VERSIONS}"* ]]; then
  echo "ERROR: Version to build is deprecated." && exit 1
fi

# NEW_ROOTFS_DIR="$(pwd)/${MGA_VERSION}/"
NEW_ROOTFS_DIR="${BUILD_DIR}/${MGA_VERSION}/${ARCH}"
PREV_ROOTFS_DIR="${BUILD_DIR}/${MGA_PREV_VERSION}/${ARCH}"
mkdir -p ${NEW_ROOTFS_DIR}
# mkdir ${TMP_DIR}


if  [ "${ARCH}" != "x86_64" ] && [ "${ARCH}" != "armv7hl" ]; then
  echo -e "ERROR: Build architecture not supported.\n" && exit 1
fi

if [ ${BUILD} -eq 1 ]; then
  # Checkout dist branch to get the rootfs file from older releases
  if [ ${CHECKOUT_DIST} -eq 1 ]; then
    prepare
  fi
  # First delete any old build
  rm -fr ${MGA_VERSION:?}/${ARCH}/${ROOTFS_FILE_NAME}
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
