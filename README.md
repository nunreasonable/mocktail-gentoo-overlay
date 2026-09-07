# mocktail-overlay

Overlay Portage **não oficial** e de terceiros com ebuilds para o
[Mocktail](https://github.com/komaruworld/mocktail), o runtime de compatibilidade que roda o
cliente Android x86-64 do Roblox no Linux.

Este overlay não tem vínculo com o projeto Mocktail, com a Roblox Corporation nem com a
VinegarHQ, e não é endossado por nenhum deles. Sou maintainer **dos ebuilds**, não do
software. Problema de empacotamento é problema daqui — não abra issue no upstream por causa
dele.

O APK do Roblox não é redistribuído por nenhum destes pacotes; o Mocktail o baixa de um
espelho de terceiros no primeiro launch.

## Pacotes

| Pacote | O que é |
|---|---|
| `app-emulation/mocktail-1.0.3` | Build a partir da fonte, da tag `1.0.3`. É o que você quer. |
| `app-emulation/mocktail-9999` | Ebuild live, segue o `main` via `git-r3`. |
| `app-emulation/mocktail-bin-1.0.3` | Binário pré-compilado do release upstream (linkado no Arch), instalado em `/opt/mocktail`. Fallback. |

`mocktail` e `mocktail-bin` se bloqueiam mutuamente: instale um ou outro.

Só `amd64` é suportado — o runtime existe para carregar objetos compartilhados Android
x86-64, e o upstream não constrói para mais nada.

## Registrando o overlay

```ini
# /etc/portage/repos.conf/mocktail-overlay.conf
[mocktail-overlay]
location = /home/daeese/overlays/mocktail
masters = gentoo
auto-sync = false
```

Os ebuilds são `~amd64`:

```
# /etc/portage/package.accept_keywords/mocktail
app-emulation/mocktail     ~amd64
app-emulation/mocktail-bin ~amd64
```

## USE flags necessárias nas dependências

O CMake do Mocktail exige `minizip.pc` (que no Gentoo só sai com `USE=minizip` no zlib) e
`webkitgtk-6.0`, cujo `REQUIRED_USE` é `any-of ( aqua wayland X )`:

```
# /etc/portage/package.use/mocktail
sys-libs/zlib               minizip
media-libs/libsdl3          vulkan opengl wayland
net-libs/webkit-gtk:6       wayland
media-libs/harfbuzz         icu
media-libs/gst-plugins-base opengl
```

As duas últimas linhas são exigidas pelas dependências do `webkit-gtk:6`, não pelo Mocktail.
Num perfil desktop com `wayland` global, só a linha do `zlib` costuma ser necessária.

## Instalando

```sh
emerge -av app-emulation/mocktail
```

Prepare-se: puxa `net-libs/webkit-gtk:6`, que é build longo.

## Como os ebuilds divergem do upstream

Duas mudanças, ambas como patch versionado em `files/`, nenhuma como `sed` inline:

- **`mocktail-system-vulkan-headers.patch`** — `third_party/Vulkan-Headers` é submódulo git e
  vem vazio no tarball. Trocamos o `add_subdirectory()` por
  `find_package(VulkanHeaders CONFIG REQUIRED)`, usando `dev-util/vulkan-headers`, que exporta
  o mesmo alvo `Vulkan::Headers`.
- **`mocktail-1.0.3-bionic-abi-exports-no-lto.patch`** — backport do fix que o upstream fez
  depois da tag 1.0.3: `src/compat/bionic_abi_exports.cc` redefine de propósito os `__*_chk`
  da glibc, e sem `-fno-lto -fno-builtin` o GCC pode dobrar a chamada de volta no próprio
  wrapper e virar recursão infinita. Não é aplicado no `9999`, que já traz o fix.

Além disso o `src_configure` desliga o helper de socket do FreeBSD
(`MOCKTAIL_BUILD_FREEBSD_SOCKET_HELPER=OFF`, que só serve ao Linuxulator e arrastaria
`llvm-core/lld`), desliga o `BUILD_TESTING` (que faria `FetchContent` do googletest pela rede)
e **não** passa `-DCMAKE_INSTALL_LIBDIR=lib` como o PKGBUILD do Arch — no Gentoo isso poria
ELF de 64 bits em `/usr/lib`, que é falha de QA sob `FEATURES=multilib-strict`.

## Licença

Os ebuilds seguem a GPL-2, como é praxe no Portage. O Mocktail em si é Apache-2.0, com
`third_party/` trazendo BSD (ANGLE, bionic/ARM), MIT (mcpelauncher-linker) e
GPL-2-with-classpath-exception (headers JNI do OpenJDK) — daí o campo `LICENSE` dos ebuilds.
