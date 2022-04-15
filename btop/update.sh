#!/bin/bash

set -e

ROOT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT_PATH}" || exit 1

version="$1"

for arch in i486 x86_64
do
    wget -qqq "https://github.com/aristocratos/btop/releases/download/v${version}/btop-${arch}-linux-musl.tbz" -O "btop-${arch}-linux-musl.tbz"

    rm -rf bin
    tar -xvjf btop-${arch}-linux-musl.tbz bin/btop

    mkdir -p $arch
    mv -f bin/btop $arch/btop
    chmod +x $arch/btop
    file ./${arch}/btop
    ./${arch}/btop --version
done

rm -f *.tbz
rm -rf bin
