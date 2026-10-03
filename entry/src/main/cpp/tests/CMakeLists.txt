cmake_minimum_required(VERSION 3.16)
project(sns_host_tests CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(../ambient ambient)
add_subdirectory(../profile profile)
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/../wrapper/CMakeLists.txt)
  add_subdirectory(../wrapper wrapper)
  set(SNS_WRAPPER_LIB sns_wrapper)
endif()

# test_main.cpp holds main(); every other test_*.cpp registers cases via TEST().
file(GLOB SNS_TEST_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/test_*.cpp)
add_executable(sns_tests ${SNS_TEST_SOURCES})
target_link_libraries(sns_tests PRIVATE sns_profile ${SNS_WRAPPER_LIB})

# The teammate's own tests and CLI, built against the vendored engine.
foreach(t test_core test_custom test_safety)
  add_executable(ambient_${t} ../ambient/tests/${t}.cpp)
  target_link_libraries(ambient_${t} PRIVATE ambient_core)
endforeach()
add_executable(wav_cli ../ambient/tools/wav_cli.cpp)
target_link_libraries(wav_cli PRIVATE ambient_core)
