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
VERSION=0.6.0

BUILD=0
PUSH=0
UPDATE_OFFICIAL=0
DEBUG=0
VERBOSE=0
SILENT=1
BUILD_DIR="$(mktemp -d)"
DEBUG_OUTPUT=" 2>&1 >/dev/null "
CLEANUP_BUILD_FILES=0
PROGRAM_NAME="build2release"

# Include functions
. ./functions.sh

trap 'term_handler' INT

while getopts bB:pr:UvVh option
do
  case "${option}"
  in
    b) BUILD=1
       ;;
    B) BUILD_DIR="$(mktemp -d -p ${OPTARG})"
       ;;
    p) PUSH=1
       ;;
    r) MIRROR=${OPTARG}
      ;;
    U) UPDATE_OFFICIAL=1
       ;;
    h) usage
       exit
       ;;
    v) VERBOSE=1
       DEBUG_OUTPUT=" 2>&1 "
       ;;
    V) DEBUG=1
       set -x
       DEBUG_OUTPUT=""
       ;;
    ?) usage
       exit
       ;;
  esac
done

print_msg "${PROGRAM_NAME} - v${VERSION}"

mkdir -p ${BUILD_DIR}/build
rm -f ${BUILD_LOG_FILE}
touch ${BUILD_LOG_FILE}

# Build images
if [[ ${BUILD} -eq 1 ]]; then
  build_image
fi

# Push dist branch
if [[  ${PUSH} -eq 1 ]]; then
  push
fi

# Update official docker library
if [[ ${UPDATE_OFFICIAL} -eq 1 ]]; then
  update_library
fi

# Cleanup after new images ar built and pushed
if [[ ${CLEANUP_BUILD_FILES} -eq 1 ]]; then
  rm -fr ${BUILD_DIR}
fi
