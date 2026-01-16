cmake_minimum_required(VERSION 3.6)

project(harbour-zsirozas LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)

# Qt
find_package(Qt5 REQUIRED COMPONENTS
    Core
    Qml
    Quick
)

# SailfishApp (IMPORTANT)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SAILFISHAPP REQUIRED sailfishapp)

add_executable(harbour-zsirozas
    main.cpp
    src/GameEngine.cpp
)

# Include paths
target_include_directories(harbour-zsirozas PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${SAILFISHAPP_INCLUDE_DIRS}
)

# Link libraries
target_link_libraries(harbour-zsirozas
    Qt5::Core
    Qt5::Qml
    Qt5::Quick
    ${SAILFISHAPP_LIBRARIES}
)
