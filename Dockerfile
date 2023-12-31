FROM debian:12.4-slim

ARG OW2_RELEASE_VERSION=2023-12-01-Build
ARG OW2_INSTALLER_NAME=open-watcom-2_0-c-linux-x64
ARG OW2_INSTALLER_SHA256=1781635c1cf76d3e7232b4de137372dccf00b166b1271359f969c50dda7dde61

# Download, verify and run the prebuilt Open Watcom v2 installer for Linux
RUN apt -y update
RUN apt -y install wget
RUN wget -P /tmp https://github.com/open-watcom/open-watcom-v2/releases/download/${OW2_RELEASE_VERSION}/${OW2_INSTALLER_NAME}
RUN echo "${OW2_INSTALLER_SHA256}  /tmp/${OW2_INSTALLER_NAME}" | sha256sum --check
RUN chmod +x /tmp/${OW2_INSTALLER_NAME}

# Workaround(s), see https://github.com/open-watcom/open-watcom-v2/wiki/Notes#core-dump-in-linux-installer

# Doesn't work
TERMINFO=/lib/terminfo

# Doesn't work either (even when I try other values such as `xterm`, `xterm-256color`, etc.)
export TERM=vt100

# Run the installer with `script` as a workaround for `Floating point exception (core dumped)`
# See also https://github.com/open-watcom/open-watcom-v2/wiki/Notes#core-dump-in-linux-installer
ARG TERM=vt100
RUN script -c "/tmp/${OW2_INSTALLER_NAME} -i"

# FIXME: update the rest below once we finally get the installer to work in a Dockerfile.

RUN 0<&- script -qefc "/tmp/${OW2_INSTALLER_NAME} -i" /dev/null | cat
RUN ls -lh /usr/bin/
RUN ls -lh /usr/bin/watcom
RUN apt -y install lbzip2
RUN tar -xf /tmp/${OW2_INSTALLER_NAME} -C /opt
RUN rm /tmp/${OW2_INSTALLER_NAME}
RUN apt -y remove wget lbzip2

# FIXME: rewrite the following ENV commands to do the same thing that `source owsetenv.sh` would do.
# Make DJGPP available in environment, as instructed at https://github.com/andrewwutw/build-djgpp#using-djgpp-compiler
ENV PATH=/opt/djgpp/i586-pc-msdosdjgpp/bin/:$PATH
ENV GCC_EXEC_PREFIX=/opt/djgpp/lib/gcc/

# FIXME: update Makefile to be compatible with WMAKE instead of GNU Make
# Test compilation with a Hello World source file and a corresponding Makefile
ADD hello_world.c /tmp
ADD hello_world_makefile /tmp
RUN make -C /tmp -f hello_world_makefile

# Verify that the compiled binary is actually a DOS executable
RUN apt -y install file
RUN file /tmp/hello.exe | grep "MS-DOS"
RUN apt -y remove file
RUN make -C /tmp -f hello_world_makefile clean
RUN rm /tmp/hello_world.c
RUN rm /tmp/hello_world_makefile

# `ps` is required when using this image for a dev container
RUN apt -y install procps
