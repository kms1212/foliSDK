# foliSDK

**foliSDK** is a comprehensive cross-compiler toolchain and system library package for **foliOS**. It provides an automated build system that downloads, patches, and compiles essential utility libraries, development tools, and an architecture-specific GCC toolchain tailored for the unique foliOS environment.

## Features

* **Custom foliOS ABI & Toolchain**: A deeply patched GCC/Binutils toolchain (`x86_64-strata-folios`, `i686-strata-folios`) designed for a clean-room OS environment:
* **Modern Library Formats**: Replaces legacy `.a` and `.so` with `.sl` (Relocatable Single ELF Object) and `.dl` (Dynamic Library).
* **Custom ELF Interpreter**: Binaries are natively linked against foliOS's custom dynamic linker (`/System/Processes/Current/RuntimeLinker.app`).
* **Linker GC as Default**: The compiler is configured by default to use `-ffunction-sections -fdata-sections` and `-Wl,--gc-sections`.
* **Layered Syscall Architecture**: Clean separation between the Kernel RunTime layer (`libstrata.dl`) and the POSIX wrapper (`libc.dl`), seamlessly linked together via GCC's custom `LIB_SPEC`.

* **System Libraries Built-in**:
* *Core & Math*: `gmp`, `mpfr`, `mpc`, `isl`
* *Cryptography*: `nettle`, `libsodium`
* *Data & Parsing*: `libxml2`, `libxslt`, `libexpat`, `yyjson`
* *Compression*: `zlib`, `bzip2`, `xz`, `lz4`, `zstd`, `libarchive`
* *System & Utilities*: `libffi`, `libuv`, `libiconv`, `ncurses`, `editline`, `readline`, `sqlite3`

* **Development Tools**:
* **CMake Integration**: Includes a custom fork (`cmake-strata`) and built-in modules (e.g., `SIDLMacros.cmake`) tailored to natively support building `foliOS` projects.
* **sidlc (SIDL Compiler)**: A custom Interface Definition Language compiler. It parses `.sidl` descriptions to automatically generate C header (`.h`) and source (`.c`) boilerplate bindings, completely avoiding global scope compound literal issues.

* **Environment Management**: Includes a structured shell activator (`folisdk-env.sh`) for macOS or Linux shells to seamlessly enter the SDK environment without polluting the host environment.

## Prerequisites

### macOS Requirements

You'll need a set of GNU tools explicitly installed on your host system:

```sh
brew install texinfo wget gnu-getopt automake libtool tcl-tk help2man
```

*(The scripts expect autoconf/automake to be present in `/opt/autoconf-...` paths as structured in the GitHub Actions, or standard macOS installations.)*

### Linux Requirements

Ensure standard GNU build utilities are installed:

```sh
sudo apt-get install build-essential bison flex texinfo wget tar tcl help2man autoconf automake libtool
```

## Building the SDK

The build is a two-step process: First, configuring the initial source references, and second, triggering the comprehensive download and compilation pipeline.

1. **Bootstrap**

    Set up local symlinks and download compiler prerequisites:

    ```sh
    ./bootstrap.sh
    ```

2. **Build**

    Compile the complete SDK for the desired architecture. It outputs an archive named `folisdk.tar.gz`.

    ```sh
    ./build.sh --arch x86_64 --jobs 8
    ```

    Available options:

    * `-a, --arch <arch>[,...]` : Set Target architecture(s) (e.g., `x86_64`, `x86_64,i686`).
    * `-b, --build-dir <path>`  : Set Build directory (default: `./build`).
    * `-j, --jobs <number>`     : Set Number of parallel compilation jobs (default: total CPUs - 1).
    * `-p, --prefix <path>`     : Installation prefix inside the archive (default: `/opt/folisdk` or `/opt/homebrew/opt/folisdk` on macOS).
    * `-o, --output <file>`     : SDK output archive filename (default: `folisdk.tar.gz`).
    * `-h, --help`              : Show help.

## Installation & Usage

### Via Homebrew (macOS Recommended)

The repository includes a ready-to-use Homebrew formula (`x86-folisdk.rb`) which automatically installs the locally generated archive (`./build/folisdk.tar.gz`) and sets up the environment script.

1. Complete the build step (archive output expected at `./build/folisdk.tar.gz`).
2. Run the Brew installation script manually:

    ```sh
    brew install --build-from-source ./x86-folisdk.rb
    ```

3. Initialize the SDK framework in your shell environment (`~/.zshrc` or `~/.bash_profile`):

    ```sh
    source $(brew --prefix folisdk)/share/folisdk/folisdk-env.sh
    ```

**Activate SDK Environment:**

```sh
folisdk_activate --arch=x86_64
```

You can now freely call gcc commands (e.g., `x86_64-strata-folios-gcc`) or configure scripts directly inside the active framework.

**Deactivate SDK Environment:**

```sh
folisdk_deactivate
```

### Developing foliOS Applications

With the SDK activated, you can write native applications using the modern `foliOS` ABI. The toolchain handles `.dl` (dynamic) and `.sl` (static) links seamlessly.

**Example `CMakeLists.txt` for a foliOS app:**

```cmake
cmake_minimum_required(VERSION 3.20)
project(HelloWorld C)

# Use the built-in SIDL macros from sidlc
include(UseSIDLC)

# Automatically compile .sidl to .c/.h bindings
sidl_generate_c(
    SRCS_VAR SIDL_SRCS
    HDRS_VAR SIDL_HDRS
    FILES "${SIDLC_INTERFACE_DIRECTORY}/byte_stream.sidl"
)

add_executable(hello_app main.c ${SIDL_SRCS})
target_include_directories(hello_app PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
```

### Manual Usage (Linux / Raw extract)

Alternatively, extract the generated artifact and add the SDK's `bin` directory into your `$PATH`.

```sh
export PATH="/path/to/extracted/opt/folisdk/bin:$PATH"
x86_64-strata-folios-gcc main.c -o out.app
x86_64-strata-folios-strip out.app
```

## Project Directory

* `build.sh` - Comprehensive automated build pipeline.
* `bootstrap.sh` - Dependency preparation script.
* `cmake-strata/` - Custom CMake fork providing native `strata-folios` toolchain support.
* `sidlc/` - The Interface Definition Language (IDL) compiler source for generating C bindings.
* `versions.cfg` - Definitive configuration setting package and library versions downloaded during the build step.
* `x86-folisdk.rb` - Packaged Homebrew install script for host environment mapping.
* `patches/` - Required upstream source modifications for successful compilation inside the SDK framework.
