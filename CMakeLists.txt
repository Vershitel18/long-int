cmake_minimum_required(VERSION 3.24...4.2)

set(CMAKE_ASM_NASM_OBJECT_FORMAT elf64)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

project(long-int LANGUAGES ASM_NASM CXX)

add_subdirectory(lib)
add_subdirectory(app)
