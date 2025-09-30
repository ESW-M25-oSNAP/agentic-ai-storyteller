cmake_minimum_required(VERSION 3.10)
project(AgentNetwork)

set(CMAKE_CXX_STANDARD 17)
add_executable(agent src/device_client.cpp src/main.cpp)
target_include_directories(agent PRIVATE include)
# Link OpenCV or TFLite if needed