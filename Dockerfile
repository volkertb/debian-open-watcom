# SPDX-License-Identifier: Apache-2.0

ARG OW2_DESTINATION_DIR=/opt/watcom

FROM debian:12.10-slim AS base
ARG OW2_RELEASE_VERSION=2025-03-01-Build
ARG OW2_INSTALLER_NAME=open-watcom-2_0-c-linux-x64
ARG OW2_INSTALLER_SHA256=6f81473452fb15c4386ac3ed1049a9f3c0c7d8f8449a099750b212ae890d1636
ARG OW2_DESTINATION_DIR

FROM base AS download-and-test

# Download and verify Open Watcom v2 installer for Linux
ADD --checksum=sha256:${OW2_INSTALLER_SHA256} https://github.com/open-watcom/open-watcom-v2/releases/download/${OW2_RELEASE_VERSION}/${OW2_INSTALLER_NAME} /tmp

RUN chmod +x /tmp/${OW2_INSTALLER_NAME}

# Run the installer with `script` as a workaround for `Floating point exception (core dumped)`
# See also https://github.com/open-watcom/open-watcom-v2/wiki/Notes#core-dump-in-linux-installer
ARG TERM=vt100
RUN script -c "/tmp/${OW2_INSTALLER_NAME} -i -dDstDir=${OW2_DESTINATION_DIR} -dFullInstall=1"

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

RUN apt -y update

# Verify that the compiled binary is actually a DOS executable
RUN apt -y install file
RUN file /tmp/hello.exe | grep "MS-DOS"

FROM base
COPY --from=download-and-test ${OW2_DESTINATION_DIR} ${OW2_DESTINATION_DIR}

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
RUN apt -y update \
    && apt -y --no-install-recommends install procps \
    && apt -y autoremove \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/* \
    && ps --version
