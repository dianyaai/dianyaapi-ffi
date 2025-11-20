REPO_ROOT := $(abspath ../../..)
CARGO ?= cargo
CC ?= gcc
CFLAGS ?= -Wall -Wextra -std=c11 -O2 -pthread
TARGET_DIR := $(REPO_ROOT)/target/release
INCLUDES := -I../../include
PORTAUDIO_LIB ?= -lportaudio
LDLIBS := -ldianyaapi_ffi $(PORTAUDIO_LIB) -lm -lpthread

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    LIB_EXT = .so
    RUN_ENV = LD_LIBRARY_PATH=$(TARGET_DIR):$$LD_LIBRARY_PATH
endif
ifeq ($(UNAME_S),Darwin)
    LIB_EXT = .dylib
    RUN_ENV = DYLD_LIBRARY_PATH=$(TARGET_DIR):$$DYLD_LIBRARY_PATH
    # 默认 Homebrew (Apple Silicon)。如使用 Intel，请改为 /usr/local
    PORTAUDIO_PREFIX ?= /opt/homebrew
    INCLUDES += -I$(PORTAUDIO_PREFIX)/include
    LDFLAGS += -L$(PORTAUDIO_PREFIX)/lib
endif
ifeq ($(OS),Windows_NT)
    LIB_EXT = .dll
endif

TARGET := main
SRC := main.c
LIB_OUTPUT := $(TARGET_DIR)/libdianyaapi_ffi$(LIB_EXT)

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(SRC) $(LIB_OUTPUT)
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) -L$(TARGET_DIR) -o $@ $< $(LDLIBS)

$(LIB_OUTPUT):
	cd $(REPO_ROOT) && $(CARGO) build --release

run: $(TARGET)
	$(RUN_ENV) ./$(TARGET)

clean:
	rm -f $(TARGET)

