# Variables to override
#
# CXX           C++ compiler
# CROSSCOMPILE	crosscompiler prefix, if any
#
MIX_APP_PATH ?= .
PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
    # Not crosscompiling, so check that we're on Linux.
    ifneq ($(shell uname -s),Linux)
        $(warning Elixir MLX90640 only works on Linux, but crosscompilation)
        $(warning is supported by defining $$CROSSCOMPILE, $$ERL_EI_INCLUDE_DIR,)
        $(warning and $$ERL_EI_LIBDIR. See Makefile for details. If using Nerves,)
        $(warning this should be done automatically.)
        $(warning .)
        $(warning Skipping C compilation unless targets explicitly passed to make.)
				DEFAULT_TARGETS = $(PREFIX)
    endif
endif

DEFAULT_TARGETS ?= $(PREFIX) $(PREFIX)/mlx90640

CXX ?= $(CROSSCOMPILE)-g++
AR ?= $(CROSSCOMPILE)-ar

ifeq ($(CROSSCOMPILE),)
	RANLIB = ranlib
else
	RANLIB = $(CROSSCOMPILE)-ranlib
endif

.PHONY: all clean

all: $(DEFAULT_TARGETS)

$(PREFIX)/mlx90640 : CXXFLAGS+=-I. -std=c++11

$(PREFIX)/mlx90640: src/main.o src/libMLX90640_API.a
	$(CXX) $^ -L./src -o $@

src/libMLX90640_API.so: src/MLX90640_API.o src/MLX90640_LINUX_I2C_Driver.o
	$(CXX) -fPIC -shared $^ -o $@

src/libMLX90640_API.a: src/MLX90640_API.o src/MLX90640_LINUX_I2C_Driver.o
	$(AR) rcs $@ $^
	$(RANLIB) $@

src/MLX90640_API.o src/MLX90640_LINUX_I2C_Driver.o : CXXFLAGS+=-fPIC -I. -shared

src/main.o : CXXFLAGS+=-std=c++11

$(PREFIX):
	mkdir -p $@

clean:
	rm -f $(PREFIX)/mlx90640
	rm -f src/*.o
	rm -f src/*.so
	rm -f src/*.a
