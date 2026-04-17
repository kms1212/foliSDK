#!/bin/bash

set -xeu

# Common Variables
OSNAME=$(uname -s)
ROOT="$PWD"

# OS-Dependent Configurations
if [ "$OSNAME" == "Darwin" ]; then
    GETOPT="/opt/homebrew/opt/gnu-getopt/bin/getopt"
else
    GETOPT="$(which getopt)"
fi


# Option Variables
PACKAGE_FORMAT_LIST=homebrew,deb
declare -a PACKAGE_FORMATS
BUILDDIR="$ROOT/build"
DESTINATION=
VERSION=0.0.1


# Parse arguments
GETOPT_OUTPUT=$("$GETOPT" -o "b:d:f:hv:" --long "build-dir:,destination:,format:,help,version:" --name "$(basename "$0")" -- "$@")

if [ $? != 0 ]; then
    exit 1
fi

eval set -- "$GETOPT_OUTPUT"

while :; do
    case "$1" in
        -h | --help)
            echo "Usage: $(basename "$0") [options]"
            echo "Options:"
            echo "  -b, --build-dir <path>        Set the build directory"
            echo "  -d, --destination <path>      Set the install destination used by build.sh"
            echo "  -f, --format <format>[,...]   Set package formats (homebrew,deb)"
            echo "  -v, --version <version>       Set package version"
            exit 0
            ;;
        -b | --build-dir)
            BUILDDIR="$2"
            shift 2
            ;;
        -d | --destination)
            DESTINATION="$2"
            shift 2
            ;;
        -f | --format)
            PACKAGE_FORMAT_LIST="$2"
            shift 2
            ;;
        -v | --version)
            VERSION="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
    esac
done

IFS="," read -r -a PACKAGE_FORMATS <<< "$PACKAGE_FORMAT_LIST"


# Default Options
if [ -z "$DESTINATION" ]; then
    if [ "$OSNAME" == "Darwin" ]; then
        DESTINATION="/opt/homebrew/opt"
    else
        DESTINATION="/opt"
    fi
fi


# Helper Functions
start_section() {
    if [ "${GITHUB_ACTIONS:-false}" == "true" ]; then
        echo "::group::$1"
    else
        echo "=== $1 ==="
    fi
}

end_section() {
    if [ "${GITHUB_ACTIONS:-false}" == "true" ]; then
        echo "::endgroup::"
    fi
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

render_template() {
    local template_path="$1"
    local output_path="$2"
    local -a sed_args

    shift 2

    sed_args=()
    while [ $# -gt 0 ]; do
        local key="${1%%=*}"
        local value="${1#*=}"
        local escaped_value

        escaped_value=$(escape_sed_replacement "$value")
        sed_args+=(-e "s|@$key@|$escaped_value|g")
        shift
    done

    mkdir -p "$(dirname "$output_path")"
    sed "${sed_args[@]}" "$template_path" > "$output_path"
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        shasum -a 256 "$1" | awk '{ print $1 }'
    fi
}

resolve_absolute_path() {
    local path="$1"

    (
        cd "$(dirname "$path")"
        printf '%s/%s\n' "$PWD" "$(basename "$path")"
    )
}

resolve_homebrew_slot() {
    local machine

    machine=$(uname -m)

    case "$OSNAME:$machine" in
        Darwin:arm64)
            echo "MACOS_ARM64"
            ;;
        Darwin:x86_64)
            echo "MACOS_X86_64"
            ;;
        Linux:x86_64)
            echo "LINUX_X86_64"
            ;;
        *)
            echo ""
            ;;
    esac
}

resolve_debian_arch() {
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --print-architecture
        return
    fi

    case "$(uname -m)" in
        x86_64)
            echo "amd64"
            ;;
        i386 | i486 | i586 | i686)
            echo "i386"
            ;;
        aarch64 | arm64)
            echo "arm64"
            ;;
        *)
            echo "Unsupported Debian host architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}


# Global Packaging Settings
PKGBUILDDIR="$BUILDDIR/pkgroot"
PACKAGE_BASEDIR="$PKGBUILDDIR$DESTINATION"
HOMEBREW_DISTDIR="$ROOT/dist/homebrew"
DPKG_DISTDIR="$ROOT/dist/dpkg"

mkdir -p "$BUILDDIR"

GENERATE_HOMEBREW=
GENERATE_DEB=

for PACKAGE_FORMAT in "${PACKAGE_FORMATS[@]}"; do
    case "$PACKAGE_FORMAT" in
        homebrew)
            GENERATE_HOMEBREW=true
            ;;
        deb | debian | dpkg)
            GENERATE_DEB=true
            ;;
        *)
            echo "Unsupported package format: $PACKAGE_FORMAT" >&2
            exit 1
            ;;
    esac
done

if [ ! -d "$PACKAGE_BASEDIR" ]; then
    echo "Package root not found: $PACKAGE_BASEDIR" >&2
    echo "Run build.sh first or specify the correct --build-dir/--destination." >&2
    exit 1
fi

declare -a PACKAGE_PATHS
while IFS= read -r PACKAGE_PATH; do
    PACKAGE_PATHS+=("$PACKAGE_PATH")
done < <(find "$PACKAGE_BASEDIR" -maxdepth 1 -mindepth 1 -type d -name "folisdk-*" | sort)

if [ ${#PACKAGE_PATHS[@]} -eq 0 ]; then
    echo "No package roots found under $PACKAGE_BASEDIR" >&2
    exit 1
fi

if [ -n "$GENERATE_HOMEBREW" ]; then
    CURRENT_HOMEBREW_SLOT=$(resolve_homebrew_slot)
    if [ -z "$CURRENT_HOMEBREW_SLOT" ]; then
        echo "Unsupported Homebrew host platform: $OSNAME/$(uname -m)" >&2
        exit 1
    fi
fi

if [ -n "$GENERATE_DEB" ] && [ "$OSNAME" != "Linux" ]; then
    echo "Debian package generation is only supported on Linux build outputs; skipping." >&2
    GENERATE_DEB=
fi

if [ -n "$GENERATE_DEB" ] && ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "dpkg-deb not found; skipping Debian package generation." >&2
    GENERATE_DEB=
fi

if [ -n "$GENERATE_DEB" ]; then
    DEBIAN_ARCH=$(resolve_debian_arch)
fi


# Package Builds
for PACKAGE_PATH in "${PACKAGE_PATHS[@]}"; do
    PACKAGE_NAME=$(basename "$PACKAGE_PATH")
    ARCHIVE_PATH="$BUILDDIR/$PACKAGE_NAME.tar.gz"
    ARCHIVE_ABS_PATH=
    ARCHIVE_URL=
    ARCHIVE_SHA256=

    HOMEBREW_TEMPLATE_PATH="$HOMEBREW_DISTDIR/$PACKAGE_NAME.rb.in"
    HOMEBREW_OUTPUT_PATH="$BUILDDIR/$PACKAGE_NAME.rb"

    DPKG_TEMPLATE_PATH="$DPKG_DISTDIR/$PACKAGE_NAME/control.in"
    DPKG_OUTPUT_PATH="$DPKG_DISTDIR/$PACKAGE_NAME/control"

    start_section "Create archive $PACKAGE_NAME"
    tar -czf "$ARCHIVE_PATH" -C "$PACKAGE_PATH" .
    end_section

    ARCHIVE_ABS_PATH=$(resolve_absolute_path "$ARCHIVE_PATH")
    ARCHIVE_URL="file://$ARCHIVE_ABS_PATH"
    ARCHIVE_SHA256=$(sha256_file "$ARCHIVE_PATH")

    if [ -n "$GENERATE_HOMEBREW" ] && [ -f "$HOMEBREW_TEMPLATE_PATH" ]; then
        start_section "Render Homebrew formula $PACKAGE_NAME"
        render_template \
            "$HOMEBREW_TEMPLATE_PATH" \
            "$HOMEBREW_OUTPUT_PATH" \
            "VERSION=$VERSION" \
            "URL_MACOS_ARM64=$ARCHIVE_URL" \
            "SHA256_MACOS_ARM64=$ARCHIVE_SHA256" \
            "URL_MACOS_X86_64=$ARCHIVE_URL" \
            "SHA256_MACOS_X86_64=$ARCHIVE_SHA256" \
            "URL_LINUX_X86_64=$ARCHIVE_URL" \
            "SHA256_LINUX_X86_64=$ARCHIVE_SHA256"
        end_section
    fi

    if [ -n "$GENERATE_DEB" ] && [ -f "$DPKG_TEMPLATE_PATH" ]; then
        start_section "Render Debian control $PACKAGE_NAME"
        render_template \
            "$DPKG_TEMPLATE_PATH" \
            "$DPKG_OUTPUT_PATH" \
            "VERSION=$VERSION" \
            "ARCH=$DEBIAN_ARCH"
        end_section

        DPKG_WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/$PACKAGE_NAME.XXXXXX")
        DPKG_STAGING_DIR="$DPKG_WORKDIR/$PACKAGE_NAME"
        DEB_OUTPUT_PATH="$BUILDDIR/${PACKAGE_NAME}_${VERSION}_${DEBIAN_ARCH}.deb"

        mkdir -p "$DPKG_STAGING_DIR/DEBIAN"
        mkdir -p "$DPKG_STAGING_DIR$DESTINATION"

        start_section "Stage Debian package $PACKAGE_NAME"
        cp -a "$PACKAGE_PATH" "$DPKG_STAGING_DIR$DESTINATION/"
        cp "$DPKG_OUTPUT_PATH" "$DPKG_STAGING_DIR/DEBIAN/control"
        end_section

        start_section "Build Debian package $PACKAGE_NAME"
        dpkg-deb --build "$DPKG_STAGING_DIR" "$DEB_OUTPUT_PATH"
        end_section

        rm -rf "$DPKG_WORKDIR"
    fi
done
