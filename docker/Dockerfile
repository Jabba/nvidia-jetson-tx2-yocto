# Build host for Yocto Project "thud" (2.6, 2018) — the release meta-tegra's
# thud-l4t-r28.3 branch requires. Yocto this old will not build on a modern
# host (Python 3.12 / glibc 2.39 / gcc 13 are all too new), so we pin the
# *build environment* to Ubuntu 18.04, which is what thud-era tooling expects,
# instead of trying to make old BitBake understand a new host.
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# Package list per the Yocto 2.6 "thud" manual's Ubuntu build-host requirements,
# plus locales (BitBake refuses to run without a UTF-8 locale) and ca-certificates
# (needed to clone https:// layers such as meta-tegra from inside the container).
RUN apt-get update && apt-get install -y --no-install-recommends \
    gawk wget git-core diffstat unzip texinfo gcc-multilib \
    build-essential chrpath socat cpio python python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping libsdl1.2-dev xterm file \
    locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# BitBake refuses to run as root, so create a non-root user. UID/GID 1000 is
# both the Docker/Ubuntu default first-user id and this host's actual user id,
# so files written into the bind-mounted sources/ and build/ directories come
# back out owned by the host user rather than root.
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd -g ${USER_GID} builder \
    && useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash builder

USER builder
WORKDIR /work
