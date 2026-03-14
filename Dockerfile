# SPDX-License-Identifier: Apache-2.0

ARG OW2_DESTINATION_DIR=/opt/watcom

FROM debian:13.3-slim AS base
ARG OW2_RELEASE_VERSION=2025-03-01-Build
ARG OW2_INSTALLER_NAME=open-watcom-2_0-c-linux-x64
ARG OW2_INSTALLER_SHA256=6f81473452fb15c4386ac3ed1049a9f3c0c7d8f8449a099750b212ae890d1636
ARG OW2_DESTINATION_DIR

FROM base AS download-and-test-ow2

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt -y update && apt -y install wget file

# Download and verify Open Watcom v2 installer for Linux
RUN --mount=type=cache,target=/Downloads \
    echo "${OW2_INSTALLER_SHA256}  /Downloads/${OW2_INSTALLER_NAME}" | sha256sum -c - \
    || (wget -O /Downloads/${OW2_INSTALLER_NAME} \
             https://github.com/open-watcom/open-watcom-v2/releases/download/${OW2_RELEASE_VERSION}/${OW2_INSTALLER_NAME} \
        && echo "${OW2_INSTALLER_SHA256}  /Downloads/${OW2_INSTALLER_NAME}" | sha256sum -c - \
        && chmod +x /Downloads/${OW2_INSTALLER_NAME})

# Run the installer with `script` as a workaround for `Floating point exception (core dumped)`
# See also https://github.com/open-watcom/open-watcom-v2/wiki/Notes#core-dump-in-linux-installer
ARG TERM=vt100
RUN --mount=type=cache,target=/Downloads \
    script -c "/Downloads/${OW2_INSTALLER_NAME} -i -dDstDir=${OW2_DESTINATION_DIR} -dFullInstall=1"

# Verify that the installation was indeed successful
RUN ls -lh ${OW2_DESTINATION_DIR}

# Verify that the /h (sub)directory with header files was also installed (apparently required `FullInstall=1`)
RUN ls -lh ${OW2_DESTINATION_DIR}/h

# Setting these ENVs is safer than having an entrypoint script sourcing ${OW2_DESTINATION_DIR}/owsetenv.sh,
# since entrypoints can be bypassed.
# Open Watcom Build Environment
ENV PATH=$OW2_DESTINATION_DIR/binl64:/opt/watcom/binl:$PATH
ENV INCLUDE=$OW2_DESTINATION_DIR/lh:$INCLUDE
ENV WATCOM=$OW2_DESTINATION_DIR
ENV EDPATH=$OW2_DESTINATION_DIR/eddat
ENV WIPFC=$OW2_DESTINATION_DIR/wipfc

# Test compilation with a Hello World source file and a corresponding Makefile
ADD hello_world.c /tmp
ADD hello_world_makefile /tmp
WORKDIR /tmp
RUN wmake -f ./hello_world_makefile

# Verify that the compiled binary is actually a DOS executable
RUN file /tmp/hello.exe | grep "MS-DOS"

FROM base AS download-and-test-jwasm

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt -y update && apt -y install build-essential wget

# Download and verify JWasm source code, so we can compile it for Linux
ARG JWASM_VERSION=2.20
ARG JWASM_ARCHIVE=v${JWASM_VERSION}.tar.gz
ARG JWASM_ARCHIVE_SHA256=a9b78dfe18af47ea9eb55fdee0bf1fb5b8b3d9a8f3d0a490cf6b2b984151ccde
RUN --mount=type=cache,target=/Downloads \
    echo "${JWASM_ARCHIVE_SHA256}  /Downloads/${JWASM_ARCHIVE}" | sha256sum -c - \
    || (wget -O /Downloads/${JWASM_ARCHIVE} \
             https://github.com/Baron-von-Riedesel/JWasm/archive/refs/tags/${JWASM_ARCHIVE} \
        && echo "${JWASM_ARCHIVE_SHA256}  /Downloads/${JWASM_ARCHIVE}" | sha256sum -c -)

WORKDIR /tmp
RUN --mount=type=cache,target=/Downloads ls -lh /Downloads && tar xf /Downloads/${JWASM_ARCHIVE}
WORKDIR /tmp/JWasm-${JWASM_VERSION}
RUN make -f GccUnix.mak
RUN mv build/GccUnixR/jwasm /usr/local/bin/

FROM base AS download-and-test-jwlink

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt -y update && apt -y install build-essential wget unzip

COPY --from=download-and-test-ow2 ${OW2_DESTINATION_DIR} ${OW2_DESTINATION_DIR}

# Setting these ENVs is safer than having an entrypoint script sourcing ${OW2_DESTINATION_DIR}/owsetenv.sh,
# since entrypoints can be bypassed.
# Open Watcom Build Environment
ENV PATH=$OW2_DESTINATION_DIR/binl64:/opt/watcom/binl:$PATH
ENV INCLUDE=$OW2_DESTINATION_DIR/lh:$INCLUDE
ENV WATCOM=$OW2_DESTINATION_DIR
ENV EDPATH=$OW2_DESTINATION_DIR/eddat
ENV WIPFC=$OW2_DESTINATION_DIR/wipfc

# Download and verify jwlink source code, so we can compile it for Linux
ARG JWLINK_VERSION=4663300c3e27c23e3e8d43ee4956661736b5c6fd
ARG JWLINK_ARCHIVE=${JWLINK_VERSION}.zip
ARG JWLINK_ARCHIVE_SHA256=8a60a227654cea9f6efa694e5db93600b1e3d0465f8515b6afee99d4079c889a
RUN --mount=type=cache,target=/Downloads \
    echo "${JWLINK_ARCHIVE_SHA256}  /Downloads/${JWLINK_ARCHIVE}" | sha256sum -c - \
    || (wget -O /Downloads/${JWLINK_ARCHIVE} https://github.com/Baron-von-Riedesel/jwlink/archive/${JWLINK_ARCHIVE} \
        && echo "${JWLINK_ARCHIVE_SHA256}  /Downloads/${JWLINK_ARCHIVE}" | sha256sum -c -)

WORKDIR /tmp/jwlink_src
RUN --mount=type=cache,target=/Downloads unzip /Downloads/${JWLINK_ARCHIVE}
WORKDIR /tmp/jwlink_src/jwlink-${JWLINK_VERSION}

# Ensure -Wno-error=incompatible-pointer-types is present in extra_c_flags, which is required for GCC 14 and later.
# (safe to add even on older GCC, which silently ignores unknown -Wno-* flags)
# Remove this workaround once this is added upstream.
RUN grep -q '\-Wno-error=incompatible-pointer-types' GccUnix.mak \
    || sed -i 's/^\(extra_c_flags\s*=.*\)/\1 -Wno-error=incompatible-pointer-types/' GccUnix.mak

# Ensure -Wno-error=implicit-function-declaration is present in extra_c_flags, which is required for GCC 14 and later.
# (safe to add even on older GCC, which silently ignores unknown -Wno-* flags)
# Remove this workaround once this is added upstream.
RUN grep -q '\-Wno-error=implicit-function-declaration' GccUnix.mak \
    || sed -i 's/^\(extra_c_flags\s*=.*\)/\1 -Wno-error=implicit-function-declaration/' GccUnix.mak

RUN make -f GccUnix.mak

RUN mv build/GccUnixR/jwlink /usr/local/bin/

FROM base

# Copy and test jwasm executable
COPY --from=download-and-test-jwasm /usr/local/bin/jwasm /usr/local/bin/
RUN jwasm -h 2>&1 | grep -q "usage:" && exit 0 || exit 1

# Copy and test jwlink executable
COPY --from=download-and-test-jwlink /usr/local/bin/jwlink /usr/local/bin/
RUN jwlink ? > /dev/null

# Copy Open Watcom installation
COPY --from=download-and-test-ow2 ${OW2_DESTINATION_DIR} ${OW2_DESTINATION_DIR}

# Setting these ENVs is safer than having an entrypoint script sourcing ${OW2_DESTINATION_DIR}/owsetenv.sh,
# since entrypoints can be bypassed.
# Open Watcom Build Environment
ENV PATH=$OW2_DESTINATION_DIR/binl64:/opt/watcom/binl:$PATH
ENV INCLUDE=$OW2_DESTINATION_DIR/lh:$INCLUDE
ENV WATCOM=$OW2_DESTINATION_DIR
ENV EDPATH=$OW2_DESTINATION_DIR/eddat
ENV WIPFC=$OW2_DESTINATION_DIR/wipfc

# Check if Open Watcom tools are still working in the runtime stage
RUN wmake -?
RUN which wcc386
RUN which wlink

# `ps` (provided by package `procps` in Debian) is required when using this image for a dev container
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt -y update \
    && apt -y --no-install-recommends install procps \
    && apt -y autoremove \
    && ps --version
