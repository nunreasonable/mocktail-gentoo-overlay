# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic optfeature xdg

DESCRIPTION="Compatibility runtime that runs the Android x86-64 Roblox client on Linux"
HOMEPAGE="https://github.com/komaruworld/mocktail"
SRC_URI="https://github.com/komaruworld/mocktail/archive/refs/tags/${PV}.tar.gz
	-> ${P}.tar.gz"

# Apache-2.0  the project itself, and the AOSP code vendored under
#             third_party/mcpelauncher-linker/{bionic,core}.
# BSD         third_party/angle_headers, plus the ARM/Linaro string routines
#             carried by third_party/mcpelauncher-linker/bionic.
# GPL-2-with-classpath-exception
#             third_party/jni, the OpenJDK JNI ABI headers.
# MIT         third_party/mcpelauncher-linker itself.
LICENSE="Apache-2.0 BSD GPL-2-with-classpath-exception MIT"
SLOT="0"
# Upstream builds for Linux x86-64 only, and the runtime exists to load Android
# x86-64 shared objects, so there is nothing to keyword on any other arch.
KEYWORDS="-* ~amd64"

# The test suite only exists with BUILD_TESTING=ON, which makes CMake
# FetchContent googletest from the network at configure time.  That is
# forbidden inside the Portage network sandbox, so there is nothing to run.
RESTRICT="test"

# Probed by CMakeLists.txt, cmake/Mocktail*.cmake and stubs/CMakeLists.txt:
#   find_package      CURL, OpenSSL, SDL3 3.4, SDL3_ttf, nlohmann_json,
#                     VulkanHeaders (after our patch)
#   pkg_check_modules yaml-0.1, minizip (virtual/minizip), capstone, gtk4,
#                     libadwaita-1>=1.6, webkitgtk-6.0, libelf, libutf8proc,
#                     fontconfig, libplacebo
#   find_path         EGL/egl.h
COMMON_DEPEND="
	>=dev-libs/capstone-5:=
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
# nlohmann_json and the Khronos headers are header-only: compiled against,
# never linked, so they have no place in RDEPEND.
DEPEND="
	${COMMON_DEPEND}
	dev-cpp/nlohmann_json
	dev-util/vulkan-headers
"
# The real Vulkan loader is only ever dlopen()ed, by SDL3 and by the Android
# libraries going through the bundled libvulkan.so shim.
RDEPEND="
	${COMMON_DEPEND}
	media-libs/vulkan-loader
	x11-themes/hicolor-icon-theme
	!app-emulation/mocktail-bin
"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}"/mocktail-system-vulkan-headers.patch
	"${FILESDIR}"/mocktail-1.0.3-bionic-abi-exports-no-lto.patch
)

src_configure() {
	# src/compat/bionic_abi_exports.cc redefines glibc's __*_chk entry points
	# on purpose.  The backported upstream patch above keeps that one
	# translation unit out of LTO and out of builtin folding; filter-lto
	# covers its siblings -- bionic_stdio_runtime.cc, libc_shim.cc and the
	# vendored bionic linker interpose glibc symbols the same way and upstream
	# has not guarded them.  A no-op when LTO is not in CFLAGS to begin with.
	#
	# _FORTIFY_SOURCE is deliberately left alone: upstream ships this exact
	# source to Arch with FORTIFY enabled, and the patch already covers the
	# only translation unit that reimplements the fortified entry points.
	filter-lto

	local mycmakeargs=(
		# third_party/libjnivm is a git submodule, so it is an empty directory
		# in the release tarball; the default ON would add_subdirectory() it
		# and fail.
		-DMOCKTAIL_ENABLE_UPSTREAM_JNIVM=OFF

		# Defaults to ON, and then hard-requires ld.lld and elfedit purely to
		# assemble a static helper for FreeBSD's Linuxulator.  Nothing on a
		# Linux host ever executes it, so switching it off drops the entire
		# llvm-core/lld build dependency.
		-DMOCKTAIL_BUILD_FREEBSD_SOCKET_HELPER=OFF

		# ON makes CMake FetchContent googletest over the network.  See
		# RESTRICT above.
		-DBUILD_TESTING=OFF

		# Compiled-in fallbacks pointing at the manifests installed below.
		-DMOCKTAIL_DEFAULT_COMPATIBILITY_MANIFEST="${EPREFIX}/usr/share/mocktail/metadata/roblox_compatibility.json"
		-DMOCKTAIL_DEFAULT_SIGNING_TRUST_MANIFEST="${EPREFIX}/usr/share/mocktail/metadata/roblox_signing_certificates.json"
	)

	# Deliberately no -DCMAKE_INSTALL_LIBDIR here.  Upstream's PKGBUILD forces
	# "lib" because Arch has no lib64, but FEATURES=multilib-strict rejects
	# 64-bit ELF under /usr/lib.  cmake.eclass already passes $(get_libdir),
	# and both the executable's INSTALL_RPATH and the compiled-in
	# MOCKTAIL_INSTALL_LIBDIR derive from that same variable, so they stay
	# consistent with wherever the libraries actually land.
	cmake_src_configure
}

pkg_postinst() {
	xdg_pkg_postinst

	# src/runtime/game_mode.cc dlopen()s libgamemode at runtime; there is no
	# build-time coupling and therefore no USE flag.
	optfeature "Feral GameMode integration" games-util/gamemode

	elog "The Roblox client APK is not distributed with Mocktail and is not"
	elog "part of this package. It is downloaded from a third-party mirror the"
	elog "first time you launch mocktail."
	elog
	elog "Only the Android x86-64 Roblox client is supported."
}
