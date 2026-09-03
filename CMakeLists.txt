cmake_minimum_required(VERSION 3.6)

project(harbour-zsirozas LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)

# Qt
find_package(Qt5 REQUIRED COMPONENTS
    Core
    LinguistTools
    Qml
    Quick
)

# SailfishApp (IMPORTANT)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SAILFISHAPP REQUIRED sailfishapp)

add_executable(harbour-zsirozas
    main.cpp
    src/GameCore.cpp
    src/GameEngine.cpp
)

set(ZSIROZAS_TRANSLATIONS
    translations/harbour-zsirozas-hu.ts
)
qt5_add_translation(ZSIROZAS_QM_FILES ${ZSIROZAS_TRANSLATIONS})
add_custom_target(harbour-zsirozas-translations ALL DEPENDS ${ZSIROZAS_QM_FILES})
add_dependencies(harbour-zsirozas harbour-zsirozas-translations)

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

option(ZSIROZAS_BUILD_TESTS "Build deterministic GameCore tests" OFF)
if(ZSIROZAS_BUILD_TESTS)
    enable_testing()
    add_executable(test_gamecore
        src/GameCore.cpp
        tests/test_gamecore.cpp
    )
    target_include_directories(test_gamecore PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    add_test(NAME gamecore COMMAND test_gamecore)

    add_executable(benchmark_ai
        src/GameCore.cpp
        tests/benchmark_ai.cpp
    )
    target_include_directories(benchmark_ai PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )
    add_test(NAME ai_strength_progression COMMAND benchmark_ai)
endif()
