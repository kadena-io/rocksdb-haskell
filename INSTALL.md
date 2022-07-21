## Ubuntu

```sh
sudo apt-get updatee
sudo apt-get install make g++ git gcc libgflags-dev libsnappy-dev libbz2-dev zlib1g-dev liblz4-dev libzstd-dev libtbb-dev libjemalloc-dev

# Update Rocksdb

```sh
mkdir tmp
cd tmp
export ROCKSDB_VERSION=6.29.5
wget https://github.com/facebook/rocksdb/archive/refs/tags/v${ROCKSDB_VERSION}.tar.gz
tar xzf v${ROCKSDB_VERSION}.tar.tz

cd "${ROCKSDB_VERSION}"
cat >> Makefile <<EOF
show_flags:
	@echo DEBUG_LEVEL=$(DEBUG_LEVEL)
	@echo LIB_MODE=$(LIB_MODE)
	@echo CXX=$(CXX)
	@echo CXXFLAGS=$(CXXFLAGS)
	@echo CFLAGS=$(CFLAGS)
	@echo LDFLAGS=$(LDFLAGS)
	@echo ARFLAGS=$(ARFLAGS)
	@echo LIB_OBJECTS=$(LIB_OBJECTS)
	@echo LIB_SOURCES_ASM=$(LIB_SOURCES_ASM)
	@echo LIB_SOURCES_C=$(LIB_SOURCES_C)
	@echo LIB_SOURCES=$(LIB_SOURCES)
EOF

DEBUG_LEVEL=0 LIB_MODE=static make show_flags
```

This generates the file util/build_version.cc and also prints the compiler flags
and sources for the build.

The sources for the cabal file are obtained from the LIB_OBJECTS.

As of rocksdb-6.29.3 there are no C are ASM sources.
