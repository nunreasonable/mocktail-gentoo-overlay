# mocktail-overlay

Third-party, **unofficial** Portage overlay with ebuilds for
[Mocktail](https://github.com/komaruworld/mocktail), the compatibility runtime that runs the
Android x86-64 Roblox client on Linux.

This overlay is not affiliated with or endorsed by the Mocktail project, the Roblox
Corporation or VinegarHQ. I maintain **the ebuilds**, not the software. A packaging problem
is a problem for this repository — do not open an issue upstream over one.

The Roblox APK is not redistributed by any of these packages; Mocktail downloads it from a
third-party mirror on first launch.

## Packages

| Package | What it is |
|---|---|
| `app-emulation/mocktail-1.0.3` | Source build from the `1.0.3` tag. This is the one you want. |
| `app-emulation/mocktail-9999` | Live ebuild, follows `main` via `git-r3`. |
| `app-emulation/mocktail-bin-1.0.3` | Prebuilt binary from the upstream release (linked on Arch), installed into `/opt/mocktail`. Fallback. |

`mocktail` and `mocktail-bin` block each other: install one or the other.

Only `amd64` is supported — the runtime exists to load Android x86-64 shared objects, and
upstream does not build for anything else.

## Registering the overlay

```ini
# /etc/portage/repos.conf/mocktail-overlay.conf
[mocktail-overlay]
location = /var/db/repos/mocktail-overlay
masters = gentoo
auto-sync = false
```

The ebuilds are `~amd64`:

```
# /etc/portage/package.accept_keywords/mocktail
app-emulation/mocktail     ~amd64
app-emulation/mocktail-bin ~amd64
```

## USE flags required on the dependencies

Mocktail's CMake requires `minizip.pc` (which on Gentoo only comes from `USE=minizip` on zlib)
and `webkitgtk-6.0`, whose `REQUIRED_USE` is `any-of ( aqua wayland X )`:

```
# /etc/portage/package.use/mocktail
sys-libs/zlib               minizip
media-libs/libsdl3          vulkan opengl wayland
net-libs/webkit-gtk:6       wayland
media-libs/harfbuzz         icu
media-libs/gst-plugins-base opengl
```

The last two lines are required by `webkit-gtk:6`'s own dependencies, not by Mocktail. On a
desktop profile with a global `wayland`, usually only the `zlib` line is needed.

## Installing

```sh
emerge -av app-emulation/mocktail
```

Be warned: it pulls in `net-libs/webkit-gtk:6`, which is a long build.

## How the ebuilds diverge from upstream

Three changes, all as versioned patches in `files/`, none as an inline `sed`:

- **`mocktail-system-vulkan-headers.patch`** — `third_party/Vulkan-Headers` is a git submodule
  and comes up empty in the tarball. The `add_subdirectory()` is replaced with
  `find_package(VulkanHeaders CONFIG REQUIRED)`, using `dev-util/vulkan-headers`, which exports
  the same `Vulkan::Headers` target.
- **`mocktail-install-libdir.patch`** — two of the runtime's helper lookups spell
  the install libdir as a literal `lib`. On Gentoo the helpers land in `lib64`, so
  `mocktail_updater` is never found: the launch policy exports
  `MOCKTAIL_UPDATE_HELPER` pointing at a path that does not exist, that value then
  wins over the fallback search, the payload update preflight is skipped, and
  startup dies on a missing `rbx_bin/libroblox.so`. The patch routes both lookups
  through the `MOCKTAIL_INSTALL_LIBDIR` macro that upstream already derives from
  `CMAKE_INSTALL_LIBDIR` and uses in two other translation units.
- **`mocktail-1.0.3-bionic-abi-exports-no-lto.patch`** — a backport of the fix upstream made
  after the 1.0.3 tag: `src/compat/bionic_abi_exports.cc` deliberately redefines glibc's
  `__*_chk` functions, and without `-fno-lto -fno-builtin` GCC may fold the call back into the
  wrapper itself and turn it into infinite recursion. Not applied to `9999`, which already
  carries the fix.

Beyond that, `src_configure` turns off the FreeBSD socket helper
(`MOCKTAIL_BUILD_FREEBSD_SOCKET_HELPER=OFF`, which only serves the Linuxulator and would drag
in `llvm-core/lld`), turns off `BUILD_TESTING` (which would `FetchContent` googletest over the
network) and does **not** pass `-DCMAKE_INSTALL_LIBDIR=lib` the way the Arch PKGBUILD does — on
Gentoo that would put 64-bit ELF objects in `/usr/lib`, a QA failure under
`FEATURES=multilib-strict`.

## License

The ebuilds are GPL-2, as is customary in Portage. Mocktail itself is Apache-2.0, with
`third_party/` bringing in BSD (ANGLE, bionic/ARM), MIT (mcpelauncher-linker) and
GPL-2-with-classpath-exception (OpenJDK JNI headers) — hence the `LICENSE` field in the
ebuilds.
