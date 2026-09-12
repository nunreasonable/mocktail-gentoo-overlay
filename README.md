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
| `app-emulation/mocktail-1.0.4` | Source build from the `1.0.4` tag. This is the one you want. |
| `app-emulation/mocktail-9999` | Live ebuild, follows `main` via `git-r3`. |
| `app-emulation/mocktail-bin-1.0.4` | Prebuilt binary from the upstream release (linked on Arch), installed into `/opt/mocktail`. Fallback. |

`mocktail` and `mocktail-bin` block each other: install one or the other.

Only `amd64` is supported — the runtime exists to load Android x86-64 shared objects, and
upstream does not build for anything else.

## Installing the overlay

The packaging lives on the orphan `gentoo-overlay` branch of this repository.
The default branch is a mirror of upstream Mocktail and carries no ebuilds, so
the branch has to be named explicitly either way.

### Clone it yourself

```sh
git clone -b gentoo-overlay --single-branch \
  https://github.com/nunreasonable/mocktail-gentoo-overlay.git \
  /var/db/repos/mocktail-overlay
```

```ini
# /etc/portage/repos.conf/mocktail-overlay.conf
[mocktail-overlay]
location = /var/db/repos/mocktail-overlay
masters = gentoo
auto-sync = false
```

Update it with `git -C /var/db/repos/mocktail-overlay pull`.

### Or let Portage manage it

```ini
# /etc/portage/repos.conf/mocktail-overlay.conf
[mocktail-overlay]
location = /var/db/repos/mocktail-overlay
masters = gentoo
auto-sync = yes
sync-type = git
sync-uri = https://github.com/nunreasonable/mocktail-gentoo-overlay.git
sync-git-clone-extra-opts = --branch gentoo-overlay
```

Then `emaint sync -r mocktail-overlay`. Portage has no `sync-branch` setting and
its git module clones whatever the default branch is, so
`sync-git-clone-extra-opts` is what pins the orphan branch; without that line
Portage clones upstream Mocktail into the repository directory and then rejects
it as invalid. Later syncs follow the branch the working tree already tracks, so
the option only matters for the first clone.

### Keywords

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
media-libs/libsdl3          vulkan opengl wayland pipewire
net-libs/webkit-gtk:6       wayland
media-libs/harfbuzz         icu
media-libs/gst-plugins-base opengl
```

The last two lines are required by `webkit-gtk:6`'s own dependencies, not by Mocktail. On a
desktop profile with a global `wayland`, usually only the `zlib` and `libsdl3` lines are
needed.

`libsdl3` needs at least one audio backend, and the `default/linux/amd64/23.0` profile
enables none of them. With none compiled in, `SDL_InitSubSystem(SDL_INIT_AUDIO)` fails with
"No available audio device", which Mocktail treats as fatal — on launch and also inside the
canary that validates a freshly downloaded payload, so the failure surfaces as "could not
update or verify the Roblox installation". `app-emulation/mocktail` therefore requires one
of `pipewire`, `pulseaudio`, `alsa`, `jack` or `sndio`; pick the one matching your sound
server. `pipewire` is what the example above assumes.

## Installing

```sh
emerge -av app-emulation/mocktail
```

Be warned: it pulls in `net-libs/webkit-gtk:6`, which is a long build.

## How the ebuilds diverge from upstream

Two changes, both as versioned patches in `files/`, neither as an inline `sed`:

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

Beyond that, `src_configure` calls `filter-lto`. `src/compat/bionic_abi_exports.cc`
deliberately redefines glibc's `__*_chk` functions, and without `-fno-lto -fno-builtin` GCC
may fold such a call back into the wrapper itself and turn it into infinite recursion.
Upstream guards that one translation unit, but `bionic_stdio_runtime.cc`, `libc_shim.cc` and
the vendored bionic linker interpose glibc symbols the same way and are not guarded, so the
filter covers them. It also turns off the FreeBSD socket helper
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
