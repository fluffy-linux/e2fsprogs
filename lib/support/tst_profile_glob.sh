# tst_profile_glob.sh --- test glob and colon handling of profile paths
#
# Usage: $(SHELL) tst_profile_glob.sh ./test_profile
#
# Fluffy Linux late-binds configuration through paths such as
# /sw/*/etc/mke2fs.conf.  This builds its own fixture tree under a
# temporary directory, so it does not depend on the host's /sw or /etc.

TEST_PROFILE=$1
case "$TEST_PROFILE" in
/*) ;;
*) TEST_PROFILE=$(pwd)/$TEST_PROFILE ;;
esac

td=$(mktemp -d "${TMPDIR:-/tmp}/tst_profile_glob.XXXXXX") || exit 1
trap 'rm -rf "$td"' 0

mkdir -p "$td/sw/pkgA/etc" "$td/sw/pkgB/etc" "$td/sw/1:pkg/etc" \
	"$td/etc" "$td/cwd" || exit 1
printf '[defaults]\n\tkey = from_pkgA\n\tvendor_only = keep_me\n' \
	> "$td/sw/pkgA/etc/mke2fs.conf"
printf '[defaults]\n\tother = from_pkgB\n' > "$td/sw/pkgB/etc/mke2fs.conf"
printf '[defaults]\n\tcolon_key = from_colon\n' > "$td/sw/1:pkg/etc/mke2fs.conf"
printf 'INVALID SYNTAX === [[[\n' > "$td/cwd/badconf"

failed=0

# expect NAME EXPECTED PATH SECTION RELATION
expect() {
	name=$1 want=$2 path=$3
	shift 3
	got=$(cd "$td/cwd" && "$TEST_PROFILE" "$path" query1 "$@" 2>&1)
	if test "$got" = "$want"; then
		echo "$name: ok"
	else
		echo "$name: failed (wanted '$want', got '$got')"
		failed=1
	fi
}

expect "wildcard path, first match" from_pkgA \
	"$td/etc/mke2fs.conf:$td/sw/*/etc/mke2fs.conf" defaults key
expect "wildcard path, later match" from_pkgB \
	"$td/etc/mke2fs.conf:$td/sw/*/etc/mke2fs.conf" defaults other
expect "colon inside bracket expressions" from_colon \
	"$td/sw/[[:alpha:]]*/etc/mke2fs.conf:$td/sw/1[a:]pkg/etc/mke2fs.conf" \
	defaults colon_key
expect "empty path entries do not read the working directory" from_pkgA \
	":$td/sw/*/etc/mke2fs.conf:" defaults key

printf '[defaults]\n\tkey = from_etc\n' > "$td/etc/mke2fs.conf"
expect "earlier file overrides wildcard match" from_etc \
	"$td/etc/mke2fs.conf:$td/sw/*/etc/mke2fs.conf" defaults key
expect "wildcard match still fills in other keys" keep_me \
	"$td/etc/mke2fs.conf:$td/sw/*/etc/mke2fs.conf" defaults vendor_only

exit $failed
