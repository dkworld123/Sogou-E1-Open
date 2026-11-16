# E1 Qt5 录音器 —— aarch64 交叉编译 Makefile
# 用法（在 WSL2 Ubuntu 22.04 内）：  make
# 交叉编译器与前缀可通过变量覆盖，例如：  make CROSS=aarch64-linux-gnu-

CROSS ?= aarch64-linux-gnu-
CXX   := $(CROSS)g++
MOC   := moc
PKG   := pkg-config
# arm64 的 pkgconfig 目录（qtbase5-dev:arm64 安装后位于此处）
PKGCONFIG_PATH ?= /usr/lib/aarch64-linux-gnu/pkgconfig

QT_MODULES = Qt5Core Qt5Qml Qt5Quick

CFLAGS += $(shell PKG_CONFIG_PATH=$(PKGCONFIG_PATH) $(PKG) --cflags $(QT_MODULES)) -O2 -Wall
LDFLAGS += $(shell PKG_CONFIG_PATH=$(PKGCONFIG_PATH) $(PKG) --libs $(QT_MODULES)) -lasound

# moc 只需 Qt 头文件路径，不要传 -O2/-Wall 等编译选项
MOCFLAGS := $(shell PKG_CONFIG_PATH=$(PKGCONFIG_PATH) $(PKG) --cflags Qt5Core)

MOC_H   := recorder.h
MOC_CPP := moc_recorder.cpp
TARGET  := e1recorder

all: $(MOC_CPP) $(TARGET)

$(MOC_CPP): $(MOC_H)
	$(MOC) $(MOCFLAGS) $< -o $@

$(TARGET): main.cpp recorder.cpp $(MOC_CPP)
	$(CXX) $(CFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -f $(TARGET) $(MOC_CPP)

.PHONY: all clean
