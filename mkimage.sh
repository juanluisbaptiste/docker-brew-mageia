#!/usr/bin/env bash
#
# Script to create Mageia official base images for integration with stackbrew
# library.
#
# Needs to be run from Mageia 6 or greater, as it requires DNF.
#
# Tested working versions are for Mageia 6 onwards (inc. cauldron).
#
#

set -e

mkimg="$(basename "$0")"

usage() {
	echo >&2 "usage: $mkimg --rootfs=rootfs_path --version=mageia_version [--mirror=url] [--package-manager=(dnf|microdnf|urpmi)] [--forcearch=ARCH] [--with-systemd] [--quiet]"
	echo >&2 "   ie: $mkimg --rootfs=. --version=6 --with-systemd"
	echo >&2 "       $mkimg --rootfs=. --version=cauldron --package-manager=dnf --with-systemd"
	echo >&2 "       $mkimg --rootfs=/tmp/rootfs --version=6 --mirror=http://mirrors.kernel.org/mageia/distrib/6/x86_64/ --with-systemd"
	echo >&2 "       $mkimg --rootfs=/tmp/rootfs --version=6 --mirror=http://mirrors.kernel.org/mageia/distrib/6/armv7hl/ --forcearch=armv7hl"
	echo >&2 "       $mkimg --rootfs=. --version=6 --package-manager=microdnf"
	exit 1
}

optTemp=$(getopt --options '+d,v:,p:,a:,s,q,h' --longoptions 'rootfs:,version:,mirror:,package-manager:,forcearch:,with-systemd,quiet,help' --name $mkimg -- "$@")
eval set -- "$optTemp"
unset optTemp

releasever=
mirror=
buildarch=
while true; do
        case "$1" in
                -d|--rootfs) dir=$2 ; shift 2 ;;
                -v|--version) releasever="$2" ; shift 2 ;;
                -m|--mirror) mirror="$2" ; shift 2 ;;
                -p|--package-manager) pkgmgr="$2" ; shift 2 ;;
                -a|--forcearch) buildarch="$2" ; shift 2 ;;
                -s|--with-systemd) systemd=true ; shift ;;
                -q|--quiet) quiet=true ; shift ;;
                -h|--help) usage ;;
                 --) shift ; break ;;
        esac
done

#dir="$1"
rootfsDir="$dir/rootfs"
#shift


#[ "$dir" ] || usage

if [ ! -x /usr/bin/dnf ]; then
	echo "Error: DNF is not installed!"
	echo "Please install DNF before continuing!"
	exit 1
fi

if [ ! -z $buildarch -a -z $mirror ]; then
	echo "Error: Mirror must be specified when setting a specific architecture!"
	exit 1
fi

if [ -z $buildarch ]; then
	# Attempt to identify target arch
	buildarch="$(rpm --eval '%{_target_cpu}')"
fi

if [ ! -z $buildarch ]; then
	# Determine if the arch is not native...
	rpmbuildarch="$(rpm --eval '%{_target_cpu}')"
	if [ "$rpmbuildarch" != "$buildarch" ]; then
		# Check for the existance of qemu-user-static
		if ! rpm --quiet --query qemu-user-static; then
			echo "Error: 'qemu-user-static' needs to be installed for non-native rootfs builds!"
			exit 1
		fi
		# To ensure qemu-user-static can be used, restart systemd-binfmt
		systemctl restart systemd-binfmt.service
	fi
fi

if [ -z $releasever ]; then
        # Attempt to match host version
        if [ -r /etc/mageia-release ]; then
                releasever="$(sed 's/^[^0-9\]*\([0-9.]\+\).*$/\1/' /etc/mageia-release)"
        else
                echo "Error: no version supplied and unable to detect host mageia version"
                exit 1
        fi
fi

if [ ! -z $mirror ]; then
        # If mirror provided, use it exclusively
	# Unfortunately, when using a mirror with --repofrompath,
	# we don't have a nice way to bootstrap with gpg keys,
	# so installations fail unless we pass --nogpgcheck
	# See: https://bugzilla.redhat.com/show_bug.cgi?id=1689591
        reposetup="--nogpgcheck --disablerepo=* --repofrompath=mgarel,$mirror/media/core/release/ --repofrompath=mgaup,$mirror/media/core/updates/ --enablerepo=mgarel --enablerepo=mgaup"
fi

if [ -z $mirror ]; then
	# Ensure we are on a Mageia system when not specifying a mirror
	if [ ! -e /etc/mageia-release ]; then
		echo "Error: No mirror specified but not on a Mageia system!"
		exit 1
	fi
        # If mirror is *not* provided, use mirrorlist
        reposetup="--disablerepo=* --enablerepo=mageia-$buildarch --enablerepo=updates-$buildarch"
fi

if [ ! -z $pkgmgr ]; then
        valid_pkg_mgrs="dnf microdnf urpmi"

        [[ $valid_pkg_mgrs =~ (^|[[:space:]])$pkgmgr($|[[:space:]]) ]] && true || echo "Invalid package manager selected." && exit 1

        echo -e "--------------------------------------"
        echo -e "Creating image to use $pkgmgr."
        echo -e "--------------------------------------\n"

fi

# Must be after the non-empty check or otherwise this will fail
if [ -z $pkgmgr ]; then
        pkgmgr="dnf urpmi"
fi

extrapkgs=""
# If urpmi is included, we *must* add curl to the target environment,
# since aria2 segfaults on some architectures, like aarch64
if [[ $pkgmgr == *"urpmi"* ]]; then
        extrapkgs="$extrapkgs curl"
fi

if [ ! -z $systemd ]; then
        echo -e "--------------------------------------"
        echo -e "Creating image with systemd support."
        echo -e "--------------------------------------\n"
        extrapkgs="$extrapkgs systemd"
fi

(
        dnf \
            $reposetup \
            --forcearch="$buildarch" \
            --installroot="$rootfsDir" \
            --releasever="$releasever" \
            --setopt=install_weak_deps=False \
            --nodocs --assumeyes ${quiet:\--quiet} \
            install basesystem-minimal $pkgmgr locales locales-en $extrapkgs
)

# Make sure /etc/resolv.conf has something useful in it
# This is being done before urpmi.addmedia call to ensure
# that will work from within the chroot...
mkdir -p "$rootfsDir/etc"
cat > "$rootfsDir/etc/resolv.conf" <<'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# Configure urpmi mirrorlist if urpmi is included on the system
# We do this in within the root to minimize impact from host,
# and so that target system architectures can be properly configured
if [[ $pkgmgr == *"urpmi"* ]]; then
        chroot "$rootfsDir" urpmi.addmedia --curl --distrib --mirrorlist "https://mirrors.mageia.org/api/mageia.$releasever.$buildarch.list"
fi

"$(dirname "$BASH_SOURCE")/.febootstrap-minimize" "$rootfsDir"

if [ -d "$rootfsDir/etc/sysconfig" ]; then
        # allow networking init scripts inside the container to work without extra steps
        echo 'NETWORKING=yes' > "$rootfsDir/etc/sysconfig/network"
fi

if [ ! -z $systemd ]; then
	#Prevent systemd from starting unneeded services
	(cd $rootfsDir/lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
        rm -f $rootfsDir/lib/systemd/system/multi-user.target.wants/*;\
        rm -f $rootfsDir/etc/systemd/system/*.wants/*;\
        rm -f $rootfsDir/lib/systemd/system/local-fs.target.wants/*; \
        rm -f $rootfsDir/lib/systemd/system/sockets.target.wants/*udev*; \
        rm -f $rootfsDir/lib/systemd/system/sockets.target.wants/*initctl*; \
        rm -f $rootfsDir/lib/systemd/system/basic.target.wants/*;\
        rm -f $rootfsDir/lib/systemd/system/anaconda.target.wants/*;
fi


# Docker mounts tmpfs at /dev and procfs at /proc so we can remove them
rm -rf "$rootfsDir/dev" "$rootfsDir/proc"
mkdir -p "$rootfsDir/dev" "$rootfsDir/proc"

if [ ! -z $systemd ]; then
    tarFile="$dir/rootfs-systemd.tar.xz"
else
    tarFile="$dir/rootfs.tar.xz"
fi

touch "$tarFile"

(
        set -x
        tar --numeric-owner -caf "$tarFile" -C "$rootfsDir" --transform='s,^./,,' .
)

( set -x; rm -rf "$rootfsDir" )
