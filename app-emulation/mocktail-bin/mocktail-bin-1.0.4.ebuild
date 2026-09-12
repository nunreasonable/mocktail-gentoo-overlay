# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker xdg

DESCRIPTION="Runs the Android x86-64 Roblox client on Linux (prebuilt binaries)"
HOMEPAGE="https://github.com/komaruworld/mocktail"
# There is no workflow in the tree that names the tagged release assets, and
# upstream does not name them consistently: the 1.0.3 asset carried the Arch
# package release (mocktail-1.0.3-2-x86_64.pkg.tar.zst) and this one does not.
# Check the actual asset name on every bump instead of deriving it.
SRC_URI="https://github.com/komaruworld/mocktail/releases/download/${PV}/mocktail-${PV}-x86_64.pkg.tar.zst"
S="${WORKDIR}"

# The archive's own .PKGINFO still says pkgver=1.0.3-2 and the binaries report
# 1.0.3, because upstream never bumped packaging/arch/PKGBUILD or
# project(Mocktail VERSION ...) at the 1.0.4 tag.  It really is the 1.0.4 build:
# it was produced on 2026-09-11 from that tree and ships the Roblox 2.736.1408
# compatibility profile that 1.0.3 does not have.

# See app-emulation/mocktail for the per-component breakdown.
LICENSE="Apache-2.0 BSD GPL-2-with-classpath-exception MIT"
SLOT="0"
KEYWORDS="-* ~amd64"

# Prebuilt binaries: leave them exactly as upstream linked them.
RESTRICT="strip"
QA_PREBUILT="opt/mocktail/*"

# Derived from readelf -d --needed over every ELF file in the upstream
# artifact, not from the source build.  Subslots are pinned wherever Gentoo's
# subslot tracks the soname these binaries were linked against, because a
# prebuilt package cannot be rebuilt on an ABI bump:
#   libcapstone.so.5           dev-libs/capstone:0/5
#   libcrypto.so.3             dev-libs/openssl:0/3
#   libplacebo.so.360          media-libs/libplacebo:0/360
#   libwebkitgtk-6.0.so.4      net-libs/webkit-gtk:6/0
#   libjavascriptcoregtk-6.0.so.1
# libutf8proc is deliberately unpinned: its Gentoo subslot is the full version
# (0/2.11.3) while the soname is only libutf8proc.so.3, so pinning would break
# the package on harmless point releases.
RDEPEND="
	dev-libs/capstone:0/5
	dev-libs/glib:2
	dev-libs/libutf8proc
	dev-libs/libyaml
	dev-libs/openssl:0/3
	gui-libs/gtk:4
	gui-libs/libadwaita:1
	media-libs/fontconfig
	media-libs/libplacebo:0/360
	media-libs/libsdl3
	media-libs/sdl3-ttf
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:6/0
	net-misc/curl
	virtual/libelf
	virtual/minizip:0/1
	virtual/zlib:0/1

	media-libs/libglvnd
	media-libs/vulkan-loader
	x11-themes/hicolor-icon-theme
	!app-emulation/mocktail
"
# .tar.zst is not in the EAPI 8 unpack() suffix list; unpacker.eclass handles it.
BDEPEND="app-arch/zstd"

src_install() {
	# Only useful under FreeBSD's Linuxulator, and it is an ELF with
	# OS/ABI = UNIX - FreeBSD, which has no business in a Linux image.
	rm usr/lib/mocktail/mocktail_freebsd_socket_helper || die

	# Keep upstream's bin/ and lib/ pair together and relocate it whole.
	# usr/bin/mocktail carries RUNPATH "$ORIGIN:$ORIGIN/../lib/mocktail" and
	# was compiled with MOCKTAIL_INSTALL_LIBDIR="lib", which
	# src/runtime/failure_dialog.cc resolves as
	# <executable dir>/../lib/mocktail -- both relative to the executable, so
	# dropping the usr/ level keeps every path valid without patchelf.
	#
	# /opt rather than /usr/lib64 on purpose: these are 64-bit ELF objects
	# hardcoded to a "lib" directory name, and /usr/lib is in
	# MULTILIB_STRICT_DIRS while /opt is not.
	dodir /opt/mocktail
	cp -a usr/bin usr/lib "${ED}"/opt/mocktail/ || die
	dosym ../../opt/mocktail/bin/mocktail /usr/bin/mocktail

	# Architecture-independent data keeps its normal FHS location: the
	# binaries were built with an absolute
	# -DMOCKTAIL_DEFAULT_COMPATIBILITY_MANIFEST under /usr/share/mocktail.
	# usr/share/licenses is skipped; Gentoo does not use that tree.
	insinto /usr/share
	doins -r usr/share/applications usr/share/icons usr/share/metainfo \
		usr/share/mocktail
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "This is the prebuilt upstream binary, linked on Arch. Prefer"
	elog "app-emulation/mocktail, which builds from source against this"
	elog "system's own libraries."
	elog
	elog "The Roblox client APK is not distributed with Mocktail and is not"
	elog "part of this package. It is downloaded from a third-party mirror the"
	elog "first time you launch mocktail."
}
