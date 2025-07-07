+++
title="Ubuntu22 CMake3.28 and GCC14"
description="Install CMake3.28 & GCC14 on Ubuntu22"
date=2024-07-07

[taxonomies]
categories = ["Doc"]
+++

## CMake 3.28

```sh
sudo apt remove --purge --auto-remove cmake
sudo apt update
sudo apt install build-essential libtool autoconf unzip wget

version=3.28
build=1
mkdir ~/temp
cd ~/temp
wget https://cmake.org/files/v$version/cmake-$version.$build.tar.gz
tar -xzvf cmake-$version.$build.tar.gz
cd cmake-$version.$build/

./bootstrap
make -j$(nproc)
sudo make install

cmake --version
```

## GCC 14

```sh
sudo apt install build-essential
sudo apt install libmpfr-dev libgmp3-dev libmpc-dev -y
wget http://ftp.gnu.org/gnu/gcc/gcc-14.1.0/gcc-14.1.0.tar.gz
tar -xf gcc-14.1.0.tar.gz
cd gcc-14.1.0
./configure -v --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu --prefix=/usr/local/gcc-14.1.0 --enable-checking=release --enable-languages=c,c++ --disable-multilib --program-suffix=-14.1.0
make
sudo make install

# Optional, make it the default
sudo update-alternatives --install /usr/bin/g++ g++ /usr/local/gcc-14.1.0/bin/g++14.1.0 14
sudo update-alternatives --install /usr/bin/gcc gcc /usr/local/gcc-14.1.0/bin/gcc14.1.0 14
```
