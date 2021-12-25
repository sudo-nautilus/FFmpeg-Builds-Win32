#!/bin/bash

PULSEAUDIO_REPO="https://gitlab.freedesktop.org/pulseaudio/pulseaudio.git"
PULSEAUDIO_COMMIT="5b000acb1a3677c71dcccf7ecd6d76c89bb3a7a0"

ffbuild_enabled() {
    [[ $TARGET == linux* ]] || return 1
    return 0
}

ffbuild_dockerbuild() {
    git clone --filter=blob:none "$PULSEAUDIO_REPO" pa
    cd pa
    git checkout "$PULSEAUDIO_COMMIT"

    # Kill build of utils and their sndfile dep
    echo > src/utils/meson.build
    echo > src/pulsecore/sndfile-util.c
    echo > src/pulsecore/sndfile-util.h
    sed -ri -e 's/(sndfile_dep = .*)\)/\1, required : false)/' meson.build
    sed -ri -e 's/shared_library/static_library/g' src/meson.build src/pulse/meson.build

    mkdir build && cd build

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --buildtype=release
        --default-library=static
        -Ddaemon=false
        -Dclient=true
        -Ddoxygen=false
        -Dgcov=false
        -Dman=false
        -Dtests=false
        -Dipv6=true
        -Dopenssl=enabled
    )

    if [[ $TARGET == linux* ]]; then
        myconf+=(
            --cross-file=/cross.meson
        )
    else
        echo "Unknown target"
        return -1
    fi

    meson "${myconf[@]}" ..
    ninja -j"$(nproc)"
    ninja install

    rm -r "$FFBUILD_PREFIX"/share

    echo "Libs.private: -ldl -lrt" >> "$FFBUILD_PREFIX"/lib/pkgconfig/libpulse.pc
    echo "Libs.private: -ldl -lrt" >> "$FFBUILD_PREFIX"/lib/pkgconfig/libpulse-simple.pc
}

ffbuild_configure() {
    echo --enable-libpulse
}

ffbuild_unconfigure() {
    echo --disable-libpulse
}
