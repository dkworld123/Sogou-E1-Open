QT += core qml quick
CONFIG += c++11 console
TARGET = e1recorder
TEMPLATE = app

SOURCES += main.cpp recorder.cpp
HEADERS += recorder.h
RESOURCES += qml.qrc

# 8 麦采集走 ALSA（设备原厂 asound.conf 已定义 8c48kmic）
# 交叉链接时需要设备侧 libasound（构建机里没有，由 build_e1_qt5.sh 通过
# LIBASOUND_LIBDIR 指到提前从设备拉取的副本）。本机构建若已装 alsa 则可省。
unix:!macx {
    DEFINES += HAS_ALSA
    LIBS   += -lasound
    libasound_libdir = $$(LIBASOUND_LIBDIR)
    !isEmpty(libasound_libdir) {
        LIBS += -L$$(LIBASOUND_LIBDIR)
    }
    # 编译期需要 ALSA 开发头(asoundlib.h)，运行期用设备自带 libasound.so
    alsa_inc = $$(ALSA_INCLUDE)
    !isEmpty(alsa_inc) {
        INCLUDEPATH += $$(ALSA_INCLUDE)
    }
}

# 静态链接 C++ 运行时，使 App 不依赖设备 libstdc++ 版本。设备是 Buildroot
# 2018.02（GCC 6.x），与交叉工具链同代但小版本可能略有差异；静态 libstdc++
# 让 App 自带 C++ 运行时，规避运行时 "symbol lookup error" 风险。工具链已自带
# libstdc++.a（已在解包后确认），故可用。Qt 设备库仍动态链接设备 libstdc++。
QMAKE_LFLAGS += -static-libstdc++
