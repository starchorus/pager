#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/release.sh -- builds the release archive for the Pager and its checksum file, reproducibly (see Deterministic). Dev machine only
# (POSIX sh + python3); it reads the repo and writes two files into the directory it is given, nothing else: no network, no device,
# no tag, no upload. Tagging, signing and publishing stay with the owner.
#
# usage: sh tools/release.sh OUTDIR       (any cwd; OUTDIR is required: there is no default place to write a release)
#        sh tools/release.sh --help
#
# What it does: runs tools/hak5-package.sh into a private temp directory, packs library/user/reconnaissance/starchorus/ (the eight files
# and the four directories above them) into OUTDIR/starchorus-<version>-pager.tar.gz, and writes OUTDIR/SHA256SUMS: the archive first,
# then every file inside it, by the path it has inside the archive, sorted. It prints the sums. It refuses (exit 2) to overwrite an
# archive or a SHA256SUMS that is already there: a release is made once, and the owner removes the old one on purpose. It refuses
# (exit 2, before anything is made) an OUTDIR that is the repo root or lies inside the repo, which holds the payload's sources, in the
# physical form of the path and by identity (the repo written in other letter case); OUTDIR is made only once the archive stands.
# Deterministic: the same sources and commit give the same bytes on one machine (zlib: below). Owner and group are root (uid 0,
# gid 0, names "root"), no user name of the maintainer is in it; every entry carries one time, the commit time of HEAD (or
# SOURCE_DATE_EPOCH, the reproducible-builds variable, where it is set to digits: for a tree with no git history); entries are in sorted
# order, directories first; file modes are 755 for the scripts and 644 for the rest; the gzip header carries no name and no time.
# The tool is python3's tarfile, not tar: the tar of this machine (bsdtar 3.5.3 on macOS) takes --uid 0 --gid 0 --uname root --gname root,
# but has no option for a fixed modification time and none for sorted names (a time would have to be set on a staging copy, and the
# flags differ again on GNU tar), so the same fields are written by tarfile, which behaves the same on every system. The gzip stream is
# made by the machine's zlib: the same machine gives the same bytes, another zlib version may compress to other bytes (the tar inside
# is identical), so compare the sums of the files inside, which SHA256SUMS lists, when the archives differ.
# Verify a download (INSTALL.md): put the archive and SHA256SUMS in one directory, unpack the archive there, run
#   shasum -a 256 -c SHA256SUMS        (sha256sum -c SHA256SUMS where that is the tool): the archive and every file read OK.
# Exit: 0 = built, 2 = usage or setup problem (no OUTDIR, an OUTDIR in the repo, an archive or SHA256SUMS already there, no commit time, python3 missing,
# the package step failed).
set -u

die() { printf 'release: %s\n' "$*" >&2; exit 2; }
R=$(cd "$(dirname "$0")/.." && pwd -P) || die "cannot find the repo"

case ${1:-} in
    -h|--help) sed -n '3,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1 (see --help)" ;;
    '') die "the output directory is required (sh tools/release.sh OUTDIR); there is no default place to write a release" ;;
esac
[ $# = 1 ] || die "one argument only, the output directory"
OUT=$1
command -v python3 >/dev/null 2>&1 || die "python3 not found on this machine"
if command -v sha256sum >/dev/null 2>&1; then SUM="sha256sum"; elif command -v shasum >/dev/null 2>&1; then SUM="shasum -a 256"; else die "neither sha256sum nor shasum found"; fi

PKGREL=library/user/reconnaissance/starchorus
VER=$(sed -n 's/^# Version: *\([0-9][0-9A-Za-z.-]*\)$/\1/p' "$R/$PKGREL/payload.sh" | head -n 1)
[ -n "$VER" ] || die "cannot read the version of $PKGREL/payload.sh"
ARCH=starchorus-$VER-pager.tar.gz

# the time of every entry: SOURCE_DATE_EPOCH when it is digits, else the commit time of HEAD
case ${SOURCE_DATE_EPOCH:-} in
    ''|*[!0-9]*) EPOCH=$(git -C "$R" log -1 --format=%ct HEAD 2>/dev/null); WHENCE="the commit time of HEAD" ;;
    *) EPOCH=$SOURCE_DATE_EPOCH; WHENCE=SOURCE_DATE_EPOCH ;;
esac
case $EPOCH in ''|*[!0-9]*) die "no commit time: this is no git work tree with a commit, and SOURCE_DATE_EPOCH is not set to a number" ;; esac
# OUTDIR is judged before anything is made: it must not be the repo root nor lie inside the repo (the payload's own sources, the
# page and the scripts are there, and an archive among them would be committed or packed by accident), in the physical form of the
# path and by identity (test -ef), so the repo written in other letter case on a case-insensitive file system is refused as well.
# The directory is made only after the package step and the archive have succeeded, so a refused or failed run leaves nothing behind.
# phys PATH: the physical path of PATH, which need not exist (the deepest existing directory is resolved, the rest appended)
phys() {
    _p=$1; _rest=
    while [ "$_p" != / ] && [ ! -d "$_p" ]; do
        _rest=/${_p##*/}$_rest
        case $_p in */*) _p=${_p%/*} ;; *) _p=. ;; esac
        [ -n "$_p" ] || _p=/
    done
    case $_rest in */..|*/../*) return 1 ;; esac
    _d=$(cd -P "$_p" 2>/dev/null && pwd -P) || return 1
    case $_d in /) printf '%s\n' "$_rest" ;; *) printf '%s%s\n' "$_d" "$_rest" ;; esac
}
OUTP=$(phys "$OUT") || die "cannot resolve $OUT (a '..' after a directory that does not exist, or no such place): choose another output directory"
case $OUTP in
    "$R"|"$R"/*) die "the output directory ($OUT) is the repo root or lies inside the repo: choose a directory outside it" ;;
esac
_w=$OUTP
while :; do
    if [ "$_w" -ef "$R" ]; then die "the output directory ($OUT) is the repo root or lies inside the repo: choose a directory outside it"; fi
    [ "$_w" != / ] || break
    _w=${_w%/*}; [ -n "$_w" ] || _w=/
done
OUT=$OUTP
[ ! -e "$OUT/$ARCH" ] && [ ! -e "$OUT/SHA256SUMS" ] || die "$OUT already holds $ARCH or SHA256SUMS: a release is made once; remove them first if you mean to make it again"

# the files come from the work tree, the time from HEAD: uncommitted changes to tracked files are said (a warning, not a refusal; after the output directory is judged, so a refused run says only why)
if [ "$WHENCE" = "the commit time of HEAD" ] && [ -n "$(git -C "$R" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    printf 'release: WARN the work tree has uncommitted changes: the archive holds them, but its time is that of HEAD, which does not describe them\n' >&2
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-release.XXXXXX") || die "cannot create a temp directory"
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

sh "$R/tools/hak5-package.sh" "$TMP/pkg" > "$TMP/pkg.out" 2>&1 || { cat "$TMP/pkg.out" >&2; die "tools/hak5-package.sh failed"; }

# shellcheck disable=SC2016   # the program is python's; nothing is meant to expand
python3 -I -c '
import gzip, os, sys, tarfile
src, base, out, epoch = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
names = sorted(os.listdir(os.path.join(src, base)))
entries = []
parts = base.split("/")
for i in range(1, len(parts) + 1):
    entries.append(("/".join(parts[:i]), None))
for n in names:
    entries.append((base + "/" + n, os.path.join(src, base, n)))
def info(name, path):
    t = tarfile.TarInfo(name + ("/" if path is None else ""))
    t.uid = t.gid = 0
    t.uname = t.gname = "root"
    t.mtime = epoch
    if path is None:
        t.type = tarfile.DIRTYPE
        t.mode = 0o755
        t.size = 0
    else:
        t.type = tarfile.REGTYPE
        t.mode = 0o755 if os.access(path, os.X_OK) else 0o644
        t.size = os.path.getsize(path)
    return t
with open(out, "wb") as raw:
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode="w", format=tarfile.USTAR_FORMAT) as tf:
            for name, path in entries:
                t = info(name, path)
                if path is None:
                    tf.addfile(t)
                else:
                    with open(path, "rb") as fh:
                        tf.addfile(t, fh)
' "$TMP/pkg" "$PKGREL" "$TMP/$ARCH" "$EPOCH" || die "building the archive failed"

# SHA256SUMS: the archive, then every file inside it by its path in the archive, sorted
{
    (cd "$TMP" && $SUM "$ARCH")
    (cd "$TMP/pkg" && find "$PKGREL" -type f | LC_ALL=C sort | while IFS= read -r f; do $SUM "$f"; done)
} > "$TMP/SHA256SUMS" || die "writing SHA256SUMS failed"
[ "$(wc -l < "$TMP/SHA256SUMS" | tr -d ' ')" = 9 ] || die "SHA256SUMS does not hold nine lines (the archive and eight files)"

mkdir -p "$OUT" || die "cannot create $OUT"
cp "$TMP/$ARCH" "$OUT/$ARCH" || die "cannot write into $OUT"
cp "$TMP/SHA256SUMS" "$OUT/SHA256SUMS" || die "cannot write into $OUT"
printf 'release: %s and SHA256SUMS written to %s (entry time %s, from %s)\n' "$ARCH" "$OUT" "$EPOCH" "$WHENCE"
cat "$OUT/SHA256SUMS"
