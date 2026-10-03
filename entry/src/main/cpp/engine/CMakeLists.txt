# Dependency-free DSP engine. Built both for the hap (via ../CMakeLists.txt) and for host tests.
file(GLOB SNS_ENGINE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
if(SNS_ENGINE_SOURCES)
  add_library(sns_engine STATIC ${SNS_ENGINE_SOURCES})
else()
  add_library(sns_engine INTERFACE)
endif()
target_include_directories(sns_engine INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
set_target_properties(sns_engine PROPERTIES POSITION_INDEPENDENT_CODE ON)
