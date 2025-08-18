# build2release - Change Log

## 0.7.0 - 2025-08-18
### Changed
- Changed method to update docker official library repo.

## 0.6.7 - 2025-02-09
### Added
- Make cloning of docker-brew-mageia repo configrable with CLONE_MGA_BREW_REPO.
### Changed
- Fixed error handling in the run_command function, now fatal errors are
  shown in verbose mode correctly.
- mkimage.sh: If a mirror is passed, use it instead of mirrorlist for final
  image. Sometimes the build fails because some mirrors are not up to date.

## 0.6.6 - 2024-05-07
### Removed
- Removed removed support for mageia 8
- Removed maintainer label from Dockerfiles

## 0.6.5 - 2024-04-01
### Added
- Added mageia 9 build for x86_64, armv7hl and aarch64 architectures.
- Moved latest tag from mga 8 to mga 9.
## Changed
- Updated Dockerfile's label name for all images.

## 0.6.4 - 2024-03-31
### Changed
- Merged PR #21: set locale to C to avoid platform dependency
- Merged PR #22: fix packager argument
- Merged PR #33: Skip restarting systemd-binfmt.service when unnecessary

### Removed
- Removed support for mageia 7

## 0.6.3 - 2021-02-26
### Added
- Build mageia 8 final images for x86_64, armv7hl and aarch64 architectures.
### Changed
- Moved latest tag from mga 7 to mga 8.

## 0.6.2 - 2021-02-08
### Added
- Added configuration of image version tags.

## 0.6.1 - 2021-01-31
### Added
- Added the build of mageia 8 RC images for x86_64, armv7hl and aarch64 architectures.

## 0.6.0 - 2021-01-16
### Added
- Added the build of Cauldron images for x86_64, armv7hl and aarch64 architectures.
- Added README file with usage instructions.

### Changed
- Fixed call to mkimage.sh which was missing parameters for --forcearch and
  --mirror.
- Removed backing up the dist branch contents as now supported versions are
  built every time.

### Removed
- Removed mageia 6 images as it is EOL now.

## 0.5.0 - 2020-04-13
### Changed
- Comlpete rewrite.

## 0.1.0 - 2018-07-25
### Added
- Initial release
