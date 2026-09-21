# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic git-r3 optfeature xdg

DESCRIPTION="Compatibility runtime that runs the Android x86-64 Roblox client on Linux"
HOMEPAGE="https://github.com/komaruworld/mocktail"
EGIT_REPO_URI="https://github.com/komaruworld/mocktail.git"
# third_party/libjnivm is replaced by MOCKTAIL_ENABLE_UPSTREAM_JNIVM=OFF and
# third_party/Vulkan-Headers by dev-util/vulkan-headers, so neither submodule
# is worth cloning.  Keeping '*' means a submodule added upstream later is
# still fetched instead of silently going missing.
EGIT_SUBMODULES=( '*' '-third_party/libjnivm' '-third_party/Vulkan-Headers' )

# See mocktail-1.0.4.ebuild for the per-component breakdown.
LICENSE="Apache-2.0 BSD GPL-2-with-classpath-exception MIT"
SLOT="0"
KEYWORDS=""
# git-r3 fetches in src_unpack, which FEATURES=network-sandbox blocks unless
# the ebuild declares itself live.
PROPERTIES="live"

# BUILD_TESTING=ON makes CMake FetchContent googletest from the network at
# configure time, which the Portage network sandbox forbids.
RESTRICT="test"

# Same probe list as 1.0.4, plus find_path(GLES3/gl3.h), which upstream added
# after the tag in cmake/MocktailPlatformGraphics.cmake for
# src/graphics/gles_text_overlay_compositor.cc.  That header comes from
# media-libs/libglvnd, already pulled in below for EGL, so nothing changes here.
COMMON_DEPEND="
	>=dev-libs/capstone-5:=
	dev-libs/glib:2
	dev-libs/libutf8proc:=
	dev-libs/libyaml
	dev-libs/openssl:=
	gui-libs/gtk:4
	>=gui-libs/libadwaita-1.6:1
	media-libs/fontconfig
	media-libs/libglvnd
	media-libs/libplacebo:=
	>=media-libs/libsdl3-3.4[vulkan]
	media-libs/sdl3-ttf
	net-libs/webkit-gtk:6=
	net-misc/curl
	virtual/libelf:=
	virtual/minizip:=
	virtual/zlib:=
"
DEPEND="
	${COMMON_DEPEND}
	dev-cpp/nlohmann_json
	dev-util/vulkan-headers
"
RDEPEND="
	${COMMON_DEPEND}
	media-libs/vulkan-loader
	x11-themes/hicolor-icon-theme
	!app-emulation/mocktail-bin
	|| (
		media-libs/libsdl3[pipewire]
		media-libs/libsdl3[pulseaudio]
		media-libs/libsdl3[alsa]
		media-libs/libsdl3[jack]
		media-libs/libsdl3[sndio]
	)
"
BDEPEND="virtual/pkgconfig"

# Same two patches as 1.0.4.  If either one stops applying, upstream has
# restructured the block it touches and the patch needs regenerating -- that is
# expected churn for a live ebuild.
PATCHES=(
	"${FILESDIR}"/mocktail-system-vulkan-headers.patch
	"${FILESDIR}"/mocktail-install-libdir.patch
)

src_configure() {
	# Upstream guards only src/compat/bionic_abi_exports.cc against LTO.
	# bionic_stdio_runtime.cc, libc_shim.cc and the vendored bionic linker
	# interpose glibc symbols in exactly the same way and are not guarded, so
	# the filter stays here too.  A no-op unless LTO is in CFLAGS.
	filter-lto

	local mycmakeargs=(
		# EGIT_SUBMODULES leaves third_party/libjnivm empty on purpose.
		-DMOCKTAIL_ENABLE_UPSTREAM_JNIVM=OFF

		# Only assembles a static helper for FreeBSD's Linuxulator, at the
		# cost of hard-requiring ld.lld and elfedit.
		-DMOCKTAIL_BUILD_FREEBSD_SOCKET_HELPER=OFF

		-DBUILD_TESTING=OFF

		-DMOCKTAIL_DEFAULT_COMPATIBILITY_MANIFEST="${EPREFIX}/usr/share/mocktail/metadata/roblox_compatibility.json"
		-DMOCKTAIL_DEFAULT_SIGNING_TRUST_MANIFEST="${EPREFIX}/usr/share/mocktail/metadata/roblox_signing_certificates.json"
	)

	# No -DCMAKE_INSTALL_LIBDIR; see mocktail-1.0.4.ebuild for why.
	cmake_src_configure
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature "Feral GameMode integration" games-util/gamemode

	elog "The Roblox client APK is not distributed with Mocktail and is not"
	elog "part of this package. It is downloaded from a third-party mirror the"
	elog "first time you launch mocktail."
	elog
	elog "Only the Android x86-64 Roblox client is supported."
}
