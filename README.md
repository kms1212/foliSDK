# foliSDK

**foliSDK** is a comprehensive cross-compiler toolchain and system library package for **foliOS**. It defines the canonical build environment for the foliOS ABI, runtime model, and binary format.

Unlike generic cross-toolchains, foliSDK intentionally removes historical Unix toolchain artifacts and aligns the entire build pipeline with the architectural principles of the foliOS runtime.

## Features

* **Custom foliOS ABI & Toolchain**: A deeply patched GCC/Binutils toolchain (`x86_64-strata-folios`, `i686-strata-folios`) designed for a clean-room OS environment.
* **Unified ELF-Based Link Model**: Eliminates legacy `ar`/`ranlib` archives in favor of a fully ELF-native static and dynamic linking strategy.
* **Modern Library Formats**:
  * `.sl` — A static library format implemented as a single relocatable ELF object generated via `ld -r`. Unlike traditional `.a` archives, `.sl` preserves full relocation metadata and enables fine-grained linker garbage collection.
  * `.dl` — A dynamic library format comparable to traditional `.so`, including SONAME support, but governed under foliOS package-level ABI management.
* **Package-Level ABI Versioning**: foliOS does not implement per-library ABI negotiation. Compatibility is guaranteed and managed at the package level rather than at individual binary granularity.
* **Custom ELF Interpreter**: Binaries are natively linked against foliOS's context-aware runtime linker (`/System/Processes/Current/RuntimeLinker.app`).  
  The `Current` node is resolved through GNT (Global Namespace Tree), allowing the system to dynamically select the appropriate runtime for the active process context.
* **Linker GC as Default**: The compiler is configured by default to use `-ffunction-sections -fdata-sections` and `-Wl,--gc-sections`, enabling aggressive dead code elimination at function granularity.
* **Layered Syscall Architecture**: Clean separation between the Kernel RunTime layer (`libstrata.dl`) and the POSIX wrapper (`libc.dl`), seamlessly linked together via GCC's custom `LIB_SPEC`.

* **System Libraries Built-in**:
* *Core & Math*: `gmp`, `mpfr`, `mpc`, `isl`
* *Cryptography*: `nettle`, `libsodium`
* *Data & Parsing*: `libxml2`, `libxslt`, `libexpat`, `yyjson`
* *Compression*: `zlib`, `bzip2`, `xz`, `lz4`, `zstd`, `libarchive`
* *System & Utilities*: `libffi`, `libuv`, `libiconv`, `ncurses`, `editline`, `readline`, `sqlite3`

* **Development Tools**:
* **CMake Integration**: Includes a custom fork (`cmake-strata`) and built-in modules (e.g., `UseSIDLC.cmake`) tailored to natively support building `foliOS` projects.
* **sidlc (SIDL Compiler)**: A custom Interface Definition Language compiler. It parses `.sidl` descriptions and generates C type headers, client bindings, server dispatch headers/sources, and combined server-client bindings for foliOS handle-based interfaces.

* **Environment Management**: Includes a structured shell activator (`folisdk-env.sh`) for macOS or Linux shells to seamlessly enter the SDK environment without polluting the host environment.

## Design Rationale

foliSDK intentionally modernizes the traditional Unix toolchain model:

* Removes `ar` archive indirection in favor of ELF-native static link units.
* Enables deterministic and reproducible builds by reducing container-level metadata variance.
* Improves compatibility with function-level garbage collection.
* Simplifies the toolchain surface area by unifying around a single object model.

GCC was selected as the base compiler due to its mature spec override system, straightforward `LIB_SPEC` customization, and deep integration with Binutils — allowing precise control over ABI behavior and runtime linkage.

## Prerequisites

### macOS Requirements

You'll need a set of GNU tools explicitly installed on your host system:

```sh
brew install texinfo wget gnu-getopt automake libtool tcl-tk help2man
```

### Linux Requirements

Ensure standard GNU build utilities are installed:

```sh
sudo apt-get install build-essential bison flex texinfo wget tar tcl help2man autoconf automake autoconf-archive pkg-config autopoint libssl-dev
```

## Building the SDK

The SDK is built by the Python graph runner in `build.py`. It downloads and verifies upstream source archives, initializes missing submodules, prepares patched sources, builds host tools, then builds one graph per target architecture.

```sh
./build.py --arch x86_64 --jobs 8
```

By default, build products are staged under `./build/pkgroot`. The staged install destination is `/opt/homebrew/opt` on macOS and `/opt` on Linux, producing package roots such as:

* `./build/pkgroot/opt/homebrew/opt/folisdk-host`
* `./build/pkgroot/opt/homebrew/opt/folisdk-x86_64`
* `./build/pkgroot/opt/homebrew/opt/folisdk-i686`

Available `build.py` options:

* `-a, --arch <arch>[,...]` : Target architecture list (default: `x86_64`; e.g., `x86_64,i686`).
* `-b, --build-dir <path>` : Build directory path (default: `./build`).
* `-d, --destination <path>` : Install destination prefix used inside `pkgroot` (default: `/opt/homebrew/opt` on macOS, `/opt` on Linux).
* `--builddir-layout` : Put host and target prefixes directly under the build directory instead of `build/pkgroot`; cannot be combined with `--destination`.
* `-j, --jobs <number>` : Parallel build job count (default: total CPUs - 1).
* `-n, --no-libs` : Build the core cross toolchain and skip the additional target library set.
* `--direct-output` : Disable the virtual terminal status UI and stream child process output directly.
* `--rerun-step <step>` : Ignore the stamp for one stamped step. Repeatable; accepts either `step` or `graph:step`.
* `--dry-run` : Print the scheduled work without executing build commands.
* `-h, --help` : Show help.

### Build Script Status

* `build.py` is the active top-level build entry point. Its `argparse` program name is still `build.sh` for compatibility in help output, but the repository currently ships and uses `build.py`.
* `build_steps.py` contains the build graph definitions and step primitives used by `build.py`. The graph order is `global-prepare`, `host-build-targets`, one `arch-<arch>` graph per selected target, and `host-cleanup`.
* Each stamped step writes `.<step>.stamp` files in the build directory. Use `--rerun-step` when one completed step needs to be forced without deleting the whole build tree.
* The build writes DOT graph files to `./build/graphs`, which can be useful when debugging dependencies.
* `make_package.sh` is the packaging step, not the compiler build step. It expects a completed staged tree from `build.py`, creates per-root `tar.gz` archives, and can render Homebrew formulae and Debian packages.

### Packaging

After `build.py` finishes, generate local package artifacts from the staged roots:

```sh
./make_package.sh --build-dir ./build --format homebrew,deb --version 0.0.1
```

Available `make_package.sh` options:

* `-b, --build-dir <path>` : Build directory containing `pkgroot` (default: `./build`).
* `-d, --destination <path>` : Install destination used by `build.py` (default: `/opt/homebrew/opt` on macOS, `/opt` on Linux).
* `-f, --format <format>[,...]` : Package formats to generate (`homebrew`, `deb`; default: `homebrew,deb`).
* `-v, --version <version>` : Package version (default: `0.0.1`).
* `-h, --help` : Show help.

`make_package.sh` scans `$build_dir/pkgroot/$destination` for `folisdk-*` roots. For each package root it creates `$build_dir/<package>.tar.gz`; when templates are present, it also renders Homebrew formulae into the build directory and Debian control files/packages on Linux. Debian package generation is skipped outside Linux or when `dpkg-deb` is unavailable.

## Installation & Usage

### Via Homebrew (macOS Recommended)

The repository includes Homebrew formula templates under `dist/homebrew`. Generate formulas with `make_package.sh`, then install the generated package formula from the build directory.

1. Complete the build and packaging steps.
2. Install the generated host formula and the target package you need:

    ```sh
    brew install --build-from-source ./build/folisdk-host.rb
    brew install --build-from-source ./build/folisdk-x86_64.rb
    ```

3. Initialize the SDK framework in your shell environment (`~/.zshrc` or `~/.bash_profile`):

    ```sh
    source $(brew --prefix folisdk-host)/share/folisdk/folisdk-env.sh
    ```

**Activate SDK Environment:**

```sh
folisdk_activate x86_64
```

You can now freely call gcc commands (e.g., `x86_64-strata-folios-gcc`) or configure scripts directly inside the active framework.

**Deactivate SDK Environment:**

```sh
folisdk_deactivate
```

## SIDL Compiler Status

`sidlc` is built as part of the host tools graph and installed by the `folisdk-host` package. The CMake integration module is installed as `UseSIDLC.cmake` under the SDK CMake module directory.

Current implementation status:

* The active compiler is the C++20 executable in `sidlc/core` and `sidlc/lang`.
* The compiler uses subcommands: `compile`, `decompile`, and `generate`.
* `.sidl` is the human-authored source format.
* `.sif` is the compiled Strata InterFace artifact used for code generation and ABI history extension. It uses the `SIF\0` magic value and stores a binary tree representation of the parsed interface, with 4-byte-aligned strings, mandatory UUID identity/prefix metadata, a root revision hash, and a per-revision hash table; it does not embed the original `.sidl` source text.
* The only implemented output language is C (`generate --lang=c`).
* The only architecture ABI currently registered in `sidlc` is `x86_64` (`generate --arch=x86_64`), with an 8-byte pointer size and six register argument slots.
* Supported SIDL declarations include `interface`, contiguous `abirevision` blocks starting at `0`, `struct`, `bitfield<T>`, `enum<T>`, and `function`.
* Supported parameter directions are `in`, `out`, and `inout`; supported type forms include built-ins, user-defined types, `ptr<T>`, `array<T>`, and `const`.
* Built-in C type mappings include `opaque`, `u8/u16/u32/u64`, `s8/s16/s32/s64`, `handle`, and `status`.
* Interface source annotations `@prefix("...")` and `@uuid("namespace-uuid", "name")` are required and are stored as SIF header metadata after compilation. Struct `@align_size(...)` is recognized and emits an aligned struct attribute.
* `generate --weak` emits weak client binding symbols.

Direct CLI usage looks like:

```sh
sidlc compile -o byte_stream.sif byte_stream.sidl
sidlc compile -b byte_stream.sif -o byte_stream.next.sif byte_stream.next.sidl

sidlc decompile -o byte_stream.sidl byte_stream.sif

sidlc generate \
    --arch=x86_64 \
    --lang=c \
    --mode=client \
    --header-dir=gen/sidl \
    --source-path=gen/sidl/byte_stream.c \
    byte_stream.sif
```

The C generator can emit:

* `*.types.h` : shared constants, UUID macros, ABI revision metadata, enums, bitfields, and structs.
* `*.h` / `*.client.c` : client-side `Open`, `Query`, and function wrappers using `StHandle_Query`, `StHandle_Call*`, and `StHandle_CallN`.
* `*.server.h` / `*.server.c` : server vtable declarations and `ServerDispatchArgs` dispatch glue.
* `*.server-client.h` / `*.server-client.c` : client-callable wrappers without the `Open`/`Query` handle binding helpers.

## Developing foliOS Applications

With the SDK activated, you can write native applications using the modern `foliOS` ABI. The toolchain handles `.dl` (dynamic) and `.sl` (static) links seamlessly.

**Example `CMakeLists.txt` for a foliOS app:**

```cmake
cmake_minimum_required(VERSION 3.20)
project(HelloWorld C)

# Use the built-in SIDL macros from sidlc
include(UseSIDLC)

# Automatically compile .sidl to .c/.h bindings
sidl_generate_c(
    CLIENT
    HEADER_DIR "${CMAKE_CURRENT_BINARY_DIR}/sidl"
    SRCS_VAR SIDL_SRCS
    HDRS_VAR SIDL_HDRS
    FILES "${SIDLC_INTERFACE_DIRECTORY}/byte_stream.sidl"
)

add_executable(hello_app main.c ${SIDL_SRCS} ${SIDL_HDRS})
target_include_directories(hello_app PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/sidl")
```

## Manual Usage (Linux / Raw extract)

Alternatively, extract the generated artifact and add the SDK's `bin` directory into your `$PATH`.

```sh
export PATH="/path/to/extracted/opt/folisdk/bin:$PATH"
x86_64-strata-folios-gcc main.c -o out.app
x86_64-strata-folios-strip out.app
```
