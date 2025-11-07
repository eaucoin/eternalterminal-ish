# syntax=docker/dockerfile:1.6
FROM --platform=linux/386 alpine:3.20 AS builder

ARG CMAKE_BUILD_TYPE=Release
ARG JOBS=4
ARG ET_VERSION=0.0.0

WORKDIR /work

# Install toolchain and headers for building against musl on 32-bit x86.
RUN --mount=type=cache,target=/var/cache/apk \
    --mount=type=cache,target=/var/lib/apk \
    apk update && \
    apk add --no-cache \
      bash \
      build-base \
      cmake \
      ninja \
      pkgconf \
      git \
      pax-utils \
      patchelf \
      protobuf-dev \
      protobuf \
      libc-dev \
      linux-headers \
      openssl-dev \
      libsodium-dev \
      zlib-dev \
      boost-dev

COPY . /work/src
WORKDIR /work/src

# Configure and build only the client binary with the system toolchain.
RUN cmake -S . -B /work/build -G Ninja \
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
      -DDISABLE_VCPKG=ON \
      -DDISABLE_SENTRY=ON \
      -DDISABLE_TELEMETRY=ON \
      -DENABLE_STACKTRACE=OFF \
      -DCMAKE_DISABLE_FIND_PACKAGE_UTempter=ON \
      -DCMAKE_DISABLE_FIND_PACKAGE_Selinux=ON \
      -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build /work/build --target et --parallel ${JOBS}

# Collect stripped artifacts in a predictable layout for export with buildx --output.
RUN install -D /work/build/et /out/usr/local/bin/et && \
    strip /out/usr/local/bin/et

# Bundle runtime shared libraries and set RPATH so the binary prefers them.
RUN mkdir -p /out/usr/local/lib/et && \
    ldd /work/build/et | awk '{print $3}' | sort -u | while read -r lib; do \
      if [ -n "$lib" ] && [ -f "$lib" ] && \
         ! echo "$lib" | grep -q 'ld-musl' && \
         ! echo "$lib" | grep -q 'ld-linux'; then \
        cp "$lib" /out/usr/local/lib/et/; \
      fi; \
    done && \
    cp /lib/ld-musl-i386.so.1 /out/usr/local/lib/et/ && \
    patchelf --set-rpath '$ORIGIN/../lib/et' /out/usr/local/bin/et && \
    patchelf --set-interpreter '/usr/local/lib/et/ld-musl-i386.so.1' /out/usr/local/bin/et && \
    find /out/usr/local/lib/et -type f -exec strip --strip-unneeded {} + || true

WORKDIR /out

# Produce distributable artifacts (tarball + standalone APK).
RUN set -euo pipefail && \
    tar -czf et-client-ish.tar.gz usr && \
    mkdir -p pkgroot && cp -a usr pkgroot/usr && \
    PKG_SIZE=$(du -sk pkgroot | awk '{print $1 * 1024}') && \
    BUILD_DATE=$(date -u +%s) && \
    mkdir -p control && \
    { \
      printf 'pkgname = et-ish\n'; \
      printf 'pkgver = %s-r0\n' "${ET_VERSION}"; \
      printf 'pkgdesc = Eternal Terminal client bundled for iSH (linux/i386, musl)\n'; \
      printf 'url = https://github.com/MisterTea/EternalTerminal\n'; \
      printf 'builddate = %s\n' "${BUILD_DATE}"; \
      printf 'arch = x86\n'; \
      printf 'origin = EternalTerminal\n'; \
      printf 'maintainer = Eternal Terminal Maintainers <maintainers@eternalterminal.invalid>\n'; \
      printf 'license = Apache-2.0\n'; \
      printf 'provides = et=%s\n' "${ET_VERSION}"; \
      printf 'size = %s\n' "${PKG_SIZE}"; \
    } > control/.PKGINFO && \
    tar -C control -czf control.tar.gz . && \
    tar -C pkgroot -czf data.tar.gz . && \
    tar -cf et-ish.apk control.tar.gz data.tar.gz && \
    rm -rf control control.tar.gz pkgroot data.tar.gz

FROM scratch AS export
COPY --from=builder /out/usr/local/bin/et /usr/local/bin/et
COPY --from=builder /out/et-client-ish.tar.gz /et-client-ish.tar.gz
COPY --from=builder /out/et-ish.apk /et-ish.apk
