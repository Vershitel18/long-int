add_executable(long-int-app)

target_compile_features(long-int-app PRIVATE cxx_std_23)
set_target_properties(long-int-app PROPERTIES CXX_EXTENSIONS OFF)

set_target_properties(long-int-app PROPERTIES POSITION_INDEPENDENT_CODE OFF)
target_link_options(long-int-app PRIVATE -no-pie "LINKER:-z,noexecstack")

target_sources(long-int-app PRIVATE "main.cpp")
target_link_libraries(long-int-app PRIVATE long-int)
