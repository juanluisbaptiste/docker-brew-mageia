# Build2release - Publish new mageia docker images

Script to automate the publishing of new or updated docker mageia linux docker images.  The image update process is roughly something like this:

1. Checkout docker-brew-mageia repository
2. Delete dist branch and recreate it from master branch. This is is done so this branch only contains one commit with the latest os root tarball files and avoid having a commit history wasting a lot of space.
3. Checkout the new dist branch.
4. Build the root tarball for all supported versions and architectures.
5. Commit the new tarballs in dist branch and force push it.
6. Update my fork of docker-library with latest upstream changes.
7. Update the mageia library file with the new commits, tags and images.
8. Commit the changes to the mageia library file and create a PR to get them merged into upstream.
9. Wait for the PR to be reviewed, accepted and merged so new images are built and published at docker hub.

All this process has been mostly automated by this script, but it still needs some work on the last steps from 7 onwards. Updating the docker-library fork works but is missing to be able to add new images to it, for now its only able to update existing ones. So for now some work is still manually done to push updated images to docker hub.

## Usage

```
$ ./build2release.sh -h
Mageia official docker image new version release script.

Usage: ./build2release.sh OPTIONS

This script will push (and optionally build using mkimage-dnf.sh) a new mageia
root filesystem to juanluisbaptiste/docker-brew-mageia.

OPTIONS:
-b    Build image.
-B    Build directory.
-p    Commit and push new images.
-r    Mirror to use.
-U    Update mageia docker library file on own fork.
-v    Verbose mode.
-V    Debug mode.
-h    Print help.
````

### Building the images

To build the images run the following command:

```
$ ./build2release.sh -b
```

That command will build all the supported mageia versions but they will not be pushed to this repo's dist branch. The supported versions are defined inside the script it self, [at the beginning](https://github.com/juanluisbaptiste/docker-brew-mageia/blob/master/build2release/functions.sh#L3) of the `functions.sh` file:

```bash
# Archquitectures to build for each supported versions
declare -A MGA_SUPPORTED_ARCHS
MGA_SUPPORTED_ARCHS[9]="x86_64 aarch64 armv7hl"
MGA_SUPPORTED_ARCHS[cauldron]="x86_64 aarch64 armv7hl"
```
The script will use a directory named `build` to store the new tarballs, but it can be changed with the -B parameter.

### Pushing the images to docker hub

After building the new images the new dist branch needs to be pushed to this repo. For this the `-p` can be used when building the tarballs:

```
$ ./build2release.sh -b -p
```

To have the new images available at docker hub the official docker library needs to be updated too. That file needs to be updated to add the new commit where the new tarballs are, update docker tags or add new images to be published. For this the `-U` parameter can be used:

```
$ ./build2release.sh -b -p -U
```
*NOTE:*  This command is still being developed and should not be used for the time being. A manual edit needs to be done for now.
