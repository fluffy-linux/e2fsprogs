# tst_conf_glob.sh --- test MKE2FS_CONFIG and E2FSCK_CONFIG wildcard paths
#
# Usage: $(SHELL) tst_conf_glob.sh MKE2FS DUMPE2FS E2FSCK LIBDIR
#
# Fluffy Linux late-binds configuration through paths such as
# /sw/*/etc/mke2fs.conf.  This builds its own fixture tree under a
# temporary directory, so it does not depend on the host's /sw or /etc.

abspath() {
	case "$1" in
	/*) echo "$1" ;;
	*) echo "$(pwd)/$1" ;;
	esac
}
MKE2FS=$(abspath "$1")
DUMPE2FS=$(abspath "$2")
E2FSCK=$(abspath "$3")
LD_LIBRARY_PATH=$(abspath "$4")${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export LD_LIBRARY_PATH
for p in "$MKE2FS" "$DUMPE2FS" "$E2FSCK"; do
	if test ! -x "$p"; then
		echo "tst_conf_glob: $p has not been built"
		exit 1
	fi
done

td=$(mktemp -d "${TMPDIR:-/tmp}/tst_conf_glob.XXXXXX") || exit 1
trap 'rm -rf "$td"' 0

mkdir -p "$td/sw/pkgA/etc" "$td/sw/pkgB/etc" "$td/cwd" || exit 1
# The fs_types values differ from mke2fs's built-in defaults, so falling back
# to those defaults cannot pass the dumpe2fs check below.
printf '[fs_types]\n\tfluffy_test = {\n\t\tblocksize = 2048\n\t\tinode_size = 512\n\t}\n' \
	> "$td/sw/pkgA/etc/mke2fs.conf"
printf '[defaults]\n\tother = from_pkgB\n' > "$td/sw/pkgB/etc/mke2fs.conf"
printf '[options]\n\tallow_cancellation = true\n\treport_verbose = true\n' \
	> "$td/sw/pkgA/etc/e2fsck.conf"
printf 'INVALID SYNTAX === [[[\n' > "$td/cwd/badconf"
cd "$td/cwd" || exit 1

failed=0
ok() { echo "$1: ok"; }
fail() { echo "$1: failed"; sed 's/^/	/' "$td/out"; failed=1; }

name="mke2fs with a wildcard MKE2FS_CONFIG"
if truncate -s 16M "$td/fs.img" &&
   MKE2FS_CONFIG="$td/sw/*/etc/mke2fs.conf" \
	"$MKE2FS" -q -F -T fluffy_test "$td/fs.img" > "$td/out" 2>&1 &&
   ! grep -q 'not defined' "$td/out"; then
	ok "$name"
else
	fail "$name"
fi

name="fs_types from the wildcard MKE2FS_CONFIG are applied"
if "$DUMPE2FS" -h "$td/fs.img" > "$td/out" 2>&1 &&
   grep -q '^Block size: *2048$' "$td/out" &&
   grep -q '^Inode size: *512$' "$td/out"; then
	ok "$name"
else
	fail "$name"
fi

name="e2fsck with a wildcard E2FSCK_CONFIG"
if E2FSCK_CONFIG="$td/sw/*/etc/e2fsck.conf" \
	"$E2FSCK" -fn "$td/fs.img" > "$td/out" 2>&1 &&
   grep -q 'inodes used' "$td/out"; then
	ok "$name"
else
	fail "$name"
fi

exit $failed
