# Makefile for C example

REPO_ROOT := $(abspath ../../..)
CARGO ?= cargo
CC = gcc
CFLAGS = -Wall -Wextra -std=c11
TARGET_DIR = $(REPO_ROOT)/target/release
LDFLAGS = -L$(TARGET_DIR) -ldianyaapi_ffi
INCLUDES = -I../../include

# 根据操作系统设置库文件扩展名和运行时路径
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    LIB_EXT = .so
    LDFLAGS += -Wl,-rpath,$(TARGET_DIR)
endif
ifeq ($(UNAME_S),Darwin)
    LIB_EXT = .dylib
    LDFLAGS += -Wl,-rpath,$(TARGET_DIR)
endif
ifeq ($(OS),Windows_NT)
    LIB_EXT = .dll
endif

TARGET = main
SRC = main.c
LIB_OUTPUT = $(TARGET_DIR)/libdianyaapi_ffi$(LIB_EXT)

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(SRC) $(LIB_OUTPUT)
	$(CC) $(CFLAGS) $(INCLUDES) -o $(TARGET) $(SRC) -L$(TARGET_DIR) $(LDFLAGS)

$(LIB_OUTPUT):
	cd $(REPO_ROOT) && $(CARGO) build --release

run: $(TARGET)
	LD_LIBRARY_PATH=$(TARGET_DIR):$$LD_LIBRARY_PATH ./$(TARGET)

clean:
	rm -f $(TARGET)

