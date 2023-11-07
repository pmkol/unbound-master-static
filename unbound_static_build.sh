#!/bin/bash
# Unbound - Static Build

[ -d ~/build/extra ] && echo "构建目录已存在，请勿二次执行脚本" && exit 0
if ! command -v cmake >/dev/null 2>&1; then
	echo "请先安装 cmake"
	exit 0
fi

echo -n "请输入 unbound 安装目录（要求绝对路径，比如 /opt/unbound）："
read INSTALL_DIR
if [ -z "$INSTALL_DIR" ]; then
	echo "unbound 安装目录不能为空"
	exit 1
fi

# 源码
unbound_source() {
	wget -q https://github.com/NLnetLabs/unbound/archive/refs/heads/master.zip -O unbound-master.zip
	unzip unbound-master.zip && rm -f unbound-master.zip
}

openssl_source() {
	wget -q https://www.openssl.org/source/openssl-1.1.1w.tar.gz
	tar -zxf openssl-1.1.1w.tar.gz && rm -f openssl-1.1.1w.tar.gz
}

libhiredis_source() {
	wget -q https://github.com/redis/hiredis/archive/refs/tags/v1.1.0.tar.gz -O hiredis-1.1.0.tar.gz
	tar -zxf hiredis-1.1.0.tar.gz && rm -f hiredis-1.1.0.tar.gz
}

libevent_source() {
	wget -q https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
	tar -zxf libevent-2.1.12-stable.tar.gz && rm -f libevent-2.1.12-stable.tar.gz
}

nghttp2_source() {
	wget -q https://github.com/nghttp2/nghttp2/releases/download/v1.54.0/nghttp2-1.54.0.tar.gz
	tar -zxf nghttp2-1.54.0.tar.gz && rm -f nghttp2-1.54.0.tar.gz
}

expat_source() {
	wget -q https://github.com/libexpat/libexpat/releases/download/R_2_5_0/expat-2.5.0.tar.gz
	tar -zxf expat-2.5.0.tar.gz && rm -f expat-2.5.0.tar.gz
}

# 变量
mkdir -p ~/build/extra && cd ~/build && TOP=$(pwd)

# 下载源码
cd $TOP/extra
openssl_source || echo "下载 openssl 失败" || exit 1
libhiredis_source || echo "下载 libhiredis 失败" || exit 1
libevent_source || echo "下载 libevent 失败" || exit 1
nghttp2_source || echo "下载 nghttp2 失败" || exit 1
expat_source || echo "下载 expat 失败" || exit 1
cd $TOP
rm -rf unbound* && unbound_source || echo "下载 unbound 失败" || exit 1

# 编译 openssl
cd $TOP/extra/openssl-*
./config --prefix=$TOP/extra/openssl no-shared CC=clang CXX=clang++
make -j$(($(nproc --all)+1))
if [ $? -ne 0 ]; then
	echo -e "\nOpenSSL 编译失败\n"
	exit 1
else
	make install
	export PKG_CONFIG_PATH=$TOP/extra/openssl/lib/pkgconfig:$PKG_CONFIG_PATH
fi

# 编译 libhiredis
cd $TOP/extra/hiredis-*
mkdir build && cd build
CC=clang CXX=clang++ cmake \
  -DCMAKE_INSTALL_PREFIX=$TOP/extra/libhiredis \
  -DENABLE_EXAMPLES=ON \
  ..
make -j$(($(nproc --all)+1))
if [ $? -ne 0 ]; then
	echo -e "\nlibhiredis 编译失败\n"
	exit 1
else
	make install
	# hack ld
	[ -d $TOP/extra/libhiredis/lib64 ] && ln -s $TOP/extra/libhiredis/lib64 $TOP/extra/libhiredis/lib
fi

# 编译 libevent
cd $TOP/extra/libevent-*
./configure --prefix=$TOP/extra/libevent --disable-shared --enable-static --disable-openssl CC=clang CXX=clang++
make -j$(($(nproc --all)+1))
if [ $? -ne 0 ]; then
	echo -e "\nlibevent 编译失败\n"
	exit 1
else
	make install
fi

# 编译 nghttp2
cd $TOP/extra/nghttp2-*
./configure \
  --prefix=$TOP/extra/libnghttp2 \
  --disable-shared \
  --enable-static \
  CC=clang CXX=clang++
make -j$(($(nproc --all)+1))
if [ $? -ne 0 ]; then
	echo -e "\nnghttp2 编译失败\n"
	exit 1
else
	make install
fi

# 编译 expat
cd $TOP/extra/expat-*
./configure --prefix=$TOP/extra/expat --without-docbook CC=clang CXX=clang++
make -j$(($(nproc --all)+1))
if [ $? -ne 0 ]; then
	echo -e "\nexpat 编译失败\n"
	exit 1
else
	make install
fi

# 编译 unbound
cd $TOP/unbound-*
sed -i '/\/\* but ignore entirely empty messages, noerror\/nodata has a soa/,/return RESPONSE_TYPE_THROWAWAY;/d' ./iterator/iter_resptype.c
make clean >/dev/null 2>&1
./configure \
  --prefix=$INSTALL_DIR \
  --disable-rpath \
  --disable-shared \
  --enable-fully-static \
  --enable-pie \
  --enable-cachedb \
  --enable-subnet \
  --without-pthreads \
  --with-libevent="$TOP/extra/libevent" \
  --with-libhiredis="$TOP/extra/libhiredis" \
  --with-libnghttp2="$TOP/extra/libnghttp2" \
  --with-ssl="$TOP/extra/openssl" \
  CFLAGS="-Ofast -funsafe-math-optimizations -ffinite-math-only -fno-rounding-math -fexcess-precision=fast -funroll-loops -ffunction-sections -fdata-sections -pipe" \
  LDFLAGS="-L$TOP/extra/expat/lib -lexpat" \
  CC=clang CXX=clang++

make -j$(($(nproc --all)+1))
if [ $? -eq 0 ]; then
	rm -rf $INSTALL_DIR
	sudo make install
	llvm-strip $INSTALL_DIR/sbin/unbound* >/dev/null 2>&1
	echo -e " \n\e[1;32munbound 编译成功，安装目录：$INSTALL_DIR\e[0m\n"
	$INSTALL_DIR/sbin/unbound -V
	echo -e " \n临时文件目录：\e[1;31m$TOP\e[0m\n"
else
	echo -e "\nunbound 编译失败\n"
fi
