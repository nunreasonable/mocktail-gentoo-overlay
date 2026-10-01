# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic optfeature xdg

# Upstream has not tagged anything after 1.0.4, but main has since picked up
# support for Roblox 2.738 and a string of runtime fixes (SIGXCPU crashes, x86
# host crashes, chat and text overlay rendering, input, voice chat start-up,
# joining a friend's game from the website).  This is main as of "po co
# chodzic, mozna latac (#183)", which upstream's CI built into the continuous
# release on the same day.
MOCKTAIL_COMMIT="77fce18a951a3ac03413a1438bf90df0fdf15e69"

DESCRIPTION="Compatibility runtime that runs the Android Roblox client on Linux"
HOMEPAGE="https://github.com/komaruworld/mocktail"
SRC_URI="https://github.com/komaruworld/mocktail/archive/${MOCKTAIL_COMMIT}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${MOCKTAIL_COMMIT}"

# See mocktail-1.0.4-r1.ebuild for the per-component breakdown.  Nothing under
# third_party/ changed after the tag; the code taken from CoderDayton/nightcap
# is Apache-2.0 like the rest of the project.
LICENSE="Apache-2.0 BSD GPL-2-with-classpath-exception MIT"
SLOT="0"
# main also builds on arm64 since upstream #152, against the Android arm64-v8a
# client, but it has not been built or run there through this overlay, so it
# gets no keyword.  No -* either: unlike 1.0.4, nothing in this tree is x86-64
# only any more.
KEYWORDS="~amd64"

# BUILD_TESTING=ON makes CMake FetchContent googletest from the network at
# configure time, which the Portage network sandbox forbids.
RESTRICT="test"

# Same probe list as 1.0.4, plus what upstream added after the tag:
#   find_path         GLES3/gl3.h, for the new GLES text overlay compositor;
#                     media-libs/libglvnd provides it, already needed for EGL.
#   pkg_check_modules libpng, linked into the libvulkan.so shim for its ETC2
#                     decoder and texture overrides.
# capstone stays on the 5 series for the runtime cs_version() check; see
# mocktail-1.0.4-r1.ebuild.
COMMON_DEPEND="
	=dev-libs/capstone-5*:=
	dev-libs/glib:2
	dev-libs/libutf8proc:=
	dev-libs/libyaml
	dev-libs/openssl:=
	gui-libs/gtk:4
	>=gui-libs/libadwaita-1.6:1
	media-libs/fontconfig
	media-libs/libglvnd
	media-libs/libplacebo:=
	media-libs/libpng:=
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

# Same two patches as 1.0.4; both still apply to this commit without fuzz.
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
		# third_party/libjnivm is a git submodule, so it is an empty directory
		# in the GitHub archive.
		-DMOCKTAIL_ENABLE_UPSTREAM_JNIVM=OFF

		# Only assembles a static helper for FreeBSD's Linuxulator, at the
		# cost of hard-requiring ld.lld and elfedit.  Upstream now switches it
		# off by itself on non-x86-64 hosts, but it still defaults to ON here.
		-DMOCKTAIL_BUILD_FREEBSD_SOCKET_HELPER=OFF

		-DBUILD_TESTING=OFF

		-DMOCKTAIL_DEFAULT_COMPATIBILITY_MANIFEST="${EPREFIX}/usr/share/mocktail/metadata/roblox_compatibility.json"
		-DMOCKTAIL_DEFAULT_SIGNING_TRUST_MANIFEST="${EPREFIX}/usr/share/mocktail/metadata/roblox_signing_certificates.json"
	)

	# No -DCMAKE_INSTALL_LIBDIR; see mocktail-1.0.4-r1.ebuild for why.
	cmake_src_configure
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature "Feral GameMode integration" games-util/gamemode

	elog "The Roblox client APK is not distributed with Mocktail and is not"
	elog "part of this package. It is downloaded from a third-party mirror the"
	elog "first time you launch mocktail."
	elog
	elog "The Roblox client ABI follows the host: x86_64 on amd64, arm64-v8a"
	elog "on arm64."
}
