cmake_minimum_required(VERSION 3.16)
project(sns_host_tests CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(../engine engine)

# test_main.cpp holds main(); every other test_*.cpp registers cases via TEST().
file(GLOB SNS_TEST_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/test_*.cpp)
add_executable(sns_tests ${SNS_TEST_SOURCES})
target_link_libraries(sns_tests PRIVATE sns_engine)

add_executable(wav_cli ../tools/wav_cli.cpp)
target_link_libraries(wav_cli PRIVATE sns_engine)
