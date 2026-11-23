cmake_minimum_required(VERSION 3.28)
project(cpp_drogon LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# clangd / clang-tidy 用に build/compile_commands.json を出力する
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# C++20 モジュールは使わないのでスキャンを切る（gcc 用のスキャンフラグが clangd / clang-tidy に渡らないように）
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# ライブラリはすべて nix devShell から（CMake の find_package で見つかる）
find_package(Drogon CONFIG REQUIRED)
find_package(cpr CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_compile_options(-Wall -Wextra -Wpedantic)

add_executable(server src/server.cpp)
target_link_libraries(server PRIVATE Drogon::Drogon)

add_executable(client src/client.cpp)
target_link_libraries(client PRIVATE cpr::cpr nlohmann_json::nlohmann_json)
