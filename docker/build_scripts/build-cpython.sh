#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh


CPYTHON_VERSION=$1
CPYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python


function pyver_dist_dir {
	# Echoes the dist directory name of given pyver, removing alpha/beta prerelease
	# Thus:
	# 3.2.1   -> 3.2.1
	# 3.7.0b4 -> 3.7.0
	echo $1 | awk -F "." '{printf "%d.%d.%d", $1, $2, $3}'
}


CPYTHON_DIST_DIR=$(pyver_dist_dir ${CPYTHON_VERSION})
fetch_source Python-${CPYTHON_VERSION}.tgz ${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}
fetch_source Python-${CPYTHON_VERSION}.tgz.asc ${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}
gpg --verify Python-${CPYTHON_VERSION}.tgz.asc
tar -xzf Python-${CPYTHON_VERSION}.tgz
pushd Python-${CPYTHON_VERSION}
PREFIX="/opt/_internal/cpython-${CPYTHON_VERSION}"
mkdir -p ${PREFIX}/lib
./configure \
  CFLAGS="-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security" \
  CPPFLAGS="-D_FORTIFY_SOURCE=2" \
  CXXFLAGS="-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security" \
  FFLAGS="-g -O2 -fstack-protector --param=ssp-buffer-size=4" \
  GCJFLAGS="-g -O2 -fstack-protector --param=ssp-buffer-size=4" \
  LDFLAGS="-Wl,-Bsymbolic-functions -Wl,-z,relro" \
  --prefix=${PREFIX} \
  --disable-shared \
  --with-ensurepip=no > /dev/null
make -j$(nproc) > /dev/null
make -j$(nproc) install > /dev/null
popd
rm -rf Python-${CPYTHON_VERSION} Python-${CPYTHON_VERSION}.tgz Python-${CPYTHON_VERSION}.tgz.asc

# we don't need libpython*.a, and they're many megabytes
find ${PREFIX} -name '*.a' -print0 | xargs -0 rm -f

# We do not need the Python test suites
find ${PREFIX} -depth \( -type d -a -name test -o -name tests \) | xargs rm -rf

# We do not need precompiled .pyc and .pyo files.
clean_pyc ${PREFIX}

# Strip ELF files found in ${PREFIX}
strip_ ${PREFIX}
