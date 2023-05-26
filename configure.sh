#!/bin/sh

prog_NAME="$(basename $0)"

err()
{
    echo "${prog_NAME}: ERROR: $@" 1>&2
}

die()
{
    echo "${prog_NAME}: ERROR: $@" 1>&2
    exit 1
}

usage()
{
    cat <<EOM 1>&2
usage: ${prog_NAME} [ OPTIONS ]
Configures the ocaml-solo5 build system.
Options:
    --prefix=DIR:
        Installation prefix (default: /usr/local).
    --target=TARGET
        Solo5 compiler toolchain to use.
    --ocaml-configure-option=OPTION
        Add an option to the OCaml compiler configuration.
EOM
    exit 1
}

OCAML_CONFIGURE_OPTIONS=
MAKECONF_PREFIX=/usr/local
while [ $# -gt 0 ]; do
    OPT="$1"

    case "${OPT}" in
        --target=*)
            CONFIG_TARGET="${OPT##*=}"
            ;;
        --prefix=*)
            MAKECONF_PREFIX="${OPT##*=}"
            ;;
        --ocaml-configure-option=*)
            OCAML_CONFIGURE_OPTIONS="${OCAML_CONFIGURE_OPTIONS} ${OPT##*=}"
            ;;
        --help)
            usage
            ;;
        *)
            err "Unknown option: '${OPT}'"
            usage
            ;;
    esac

    shift
done

[ -z "${CONFIG_TARGET}" ] && die "The --target option needs to be specified."

# SoC specific directory check for Solo5 frt
if [ -n "${PLATFORM_DIR}" ] && [ ! -e ${PLATFORM_DIR}/Makefile.soc ]; then
    die "Required file not found: ${PLATFORM_DIR}/Makefile.soc"
fi

MAKECONF_CFLAGS=""
MAKECONF_CC="$CONFIG_TARGET-cc"
MAKECONF_LD="$CONFIG_TARGET-ld"
MAKECONF_AS="$MAKECONF_CC -c"

# Use an architecture specific 'ar' command for solo5-frt and apply SoC 
# specific configuration.
case "${CONFIG_TARGET}" in
    am64x-r5-*|rt1176-m7-*)
        MAKECONF_AR="$CONFIG_TARGET-ar"
        MAKECONF_FRT=1
        ;;
esac

BUILD_TRIPLET="$($MAKECONF_CC -dumpmachine)"
OCAML_BUILD_ARCH=

# Canonicalize BUILD_ARCH and set OCAML_BUILD_ARCH. The former is for autoconf,
# the latter for the rest of the OCaml build system.
case "${BUILD_TRIPLET}" in
    amd64-*|x86_64-*)
        BUILD_ARCH="x86_64"
        OCAML_BUILD_ARCH="amd64"
        ;;
    aarch64-*)
        BUILD_ARCH="aarch64"
        OCAML_BUILD_ARCH="arm64"
        ;;
    arm-none-eabi)
        case "${CONFIG_TARGET}" in
            am64x-r5-*)
                BUILD_ARCH="am64x-r5"
                OCAML_BUILD_ARCH="arm"
                ;;
            rt1176-m7-*)
                BUILD_ARCH="rt1176-m7"
                OCAML_BUILD_ARCH="arm"
                ;;
        esac
        ;;
    *)
        die "Unsupported architecture: ${BUILD_TRIPLET}"
        ;;
esac

EXTRA_LIBS=
case "${OCAML_BUILD_ARCH}" in
    arm64|arm)
        EXTRA_LIBS="$EXTRA_LIBS -lgcc" || exit 1
        ;;
esac

cat <<EOM >Makeconf
MAKECONF_PREFIX=${MAKECONF_PREFIX}
MAKECONF_CFLAGS=${MAKECONF_CFLAGS}
MAKECONF_TOOLCHAIN=${CONFIG_TARGET}
MAKECONF_CC=${MAKECONF_CC}
MAKECONF_LD=${MAKECONF_LD}
MAKECONF_AS=${MAKECONF_AS}
MAKECONF_AR=${MAKECONF_AR}
MAKECONF_BUILD_ARCH=${BUILD_ARCH}
MAKECONF_OCAML_BUILD_ARCH=${OCAML_BUILD_ARCH}
MAKECONF_OCAML_CONFIGURE_OPTIONS=${OCAML_CONFIGURE_OPTIONS}
MAKECONF_NOLIBC_SYSDEP_OBJS=sysdeps_solo5.o
MAKECONF_EXTRA_LIBS=${EXTRA_LIBS}
MAKECONF_FRT=${MAKECONF_FRT}
MAKECONF_PLATFORM_DIR=${PLATFORM_DIR}
EOM
