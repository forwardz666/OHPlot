cmake_minimum_required(VERSION 3.4.1)
project(qohosWrapper)

add_library(qohos SHARED qohos.cpp)
target_link_libraries(qohos PUBLIC libace_napi.z.so libhilog_ndk.z.so libEGL.so libGLESv3.so libace_ndk.z.so)
