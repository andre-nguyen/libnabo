cmake_minimum_required(VERSION 3.16)

if (NOT CMAKE_VERSION VERSION_LESS "3.1")
	cmake_policy(SET CMP0054 NEW)
endif ()

set(LIB_NAME nabo)
project("lib${LIB_NAME}"
	VERSION 1.0.7
	LANGUAGES CXX)

include(cmake/utils.cmake)
nabo_generate_version_header()

# Documentation
option(LIBNABO_BUILD_DOXYGEN "Build libnabo doxygen documentation" ON)
if (LIBNABO_BUILD_DOXYGEN)
  set(DOXYFILE_LATEX false)
  include(UseDoxygen.cmake)
endif()

# Switch on warnings.
if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /Wall")
else ()
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")
endif ()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(GNUInstallDirs)

find_package(Eigen3 3.3 REQUIRED)

# optionally, opencl
# OpenCL disabled as its code is not up-to-date with API
set(USE_OPEN_CL FALSE CACHE BOOL "Set to TRUE to look for OpenCL")
if (USE_OPEN_CL)
	find_package(OpenCL)
	if (OpenCL_FOUND)
		add_definitions(-DHAVE_OPENCL)
		set(EXTRA_LIBS ${OpenCL_LIBRARIES} ${EXTRA_LIBS})
		include_directories(${OpenCL_INCLUDE_DIRS})
		add_definitions(-DOPENCL_SOURCE_DIR=\"${CMAKE_SOURCE_DIR}/nabo/opencl/\")
		message("OpenCL enabled and found, enabling CL support")
	else (OPENCL_INCLUDE_DIR AND OPENCL_LIBRARIES)
		message("OpenCL enabled but not found, disabling CL support")
	endif ()
else ()
	message("OpenCL disabled, not looking for it")
endif ()


# main nabo lib
add_library(${LIB_NAME}
	nabo/nabo.cpp
	nabo/brute_force_cpu.cpp
	nabo/kdtree_cpu.cpp
	nabo/kdtree_opencl.cpp
)

if (BUILD_SHARED_LIBS)
	install(TARGETS ${LIB_NAME} LIBRARY DESTINATION lib)
else ()
	if (NOT MSVC)
		target_compile_options(${LIB_NAME} PRIVATE -fPIC)
	endif()
	install(TARGETS ${LIB_NAME} ARCHIVE DESTINATION lib)
endif ()
set_target_properties(${LIB_NAME} PROPERTIES VERSION "${PROJECT_VERSION}" SOVERSION 1)

target_link_libraries(${LIB_NAME} PUBLIC
	Eigen3::Eigen
)

target_include_directories(${LIB_NAME} PUBLIC
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
  )

# openmp
set(USE_OPEN_MP TRUE CACHE BOOL "Set to FALSE to not use OpenMP")
if (USE_OPEN_MP)
	find_package(OpenMP)
	if (OPENMP_FOUND)
		target_compile_options(${LIB_NAME} PRIVATE -fopenmp ${OpenMP_CXX_FLAGS})
		target_compile_definitions(${LIB_NAME} PRIVATE HAVE_OPENMP)
		target_link_libraries(${LIB_NAME} PUBLIC OpenMP::OpenMP_CXX)
	endif()
endif ()


# create doc before installing
set(DOC_INSTALL_TARGET "share/doc/${PROJECT_NAME}/api" CACHE STRING "Target where to install doxygen documentation")
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/include/nabo_version.h
        DESTINATION include/nabo)
install(FILES nabo/nabo.h DESTINATION include/nabo)
install(FILES nabo/third_party/any.hpp DESTINATION include/nabo/third_party)
install(FILES README.md DESTINATION share/doc/${PROJECT_NAME})
if (DOXYGEN_FOUND)
	install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/doc/html DESTINATION ${DOC_INSTALL_TARGET})
endif (DOXYGEN_FOUND)

enable_testing()


option(LIBNABO_BUILD_EXAMPLES "Build libnabo examples" ON)
if (LIBNABO_BUILD_EXAMPLES)
  add_subdirectory(examples)
endif()

option(LIBNABO_BUILD_TESTS "Build libnabo tests" ON)
if(LIBNABO_BUILD_TESTS)
  add_subdirectory(tests)
endif()

option(LIBNABO_BUILD_PYTHON "Build libnabo python" ON)
if(LIBNABO_BUILD_PYTHON)
  add_subdirectory(python)
endif()

# Install package manifest for catkin/colcon
install(FILES package.xml DESTINATION share/libnabo)

#=============================================
# to allow find_package() on libnabo
#=============================================
#
# the following case be used in an external project requiring libnabo:
#  ...
#  find_package(libnabo)
#  include_directories(${libnabo_INCLUDE_DIRS})
#  target_link_libraries(executableName ${libnabo_LIBRARIES})
#  ...

# NOTE: the following will support find_package for 1) local build (make) and 2) for installed files (make install)

# 1- local build #

# Register the local build in case one doesn't use "make install"
export(PACKAGE libnabo)

# 'make install' to the correct locations (provided by GNUInstallDirs).
install(TARGETS ${LIB_NAME} EXPORT ${PROJECT_NAME}-targets
    ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})  # This is for Windows

add_library(${PROJECT_NAME}::${LIB_NAME} ALIAS ${LIB_NAME})

# This makes the project importable from the install directory
# Put config file in per-project dir (name MUST match), can also
# just go into 'cmake'.
install(
	EXPORT ${PROJECT_NAME}-targets
	DESTINATION share/${PROJECT_NAME}/cmake
	NAMESPACE ${PROJECT_NAME}::
)

# This makes the project importable from the build directory
export(
	TARGETS ${LIB_NAME}
	FILE ${PROJECT_NAME}-targets.cmake
	NAMESPACE ${PROJECT_NAME}::
)


# Create variable with the library location
set(libnabo_library $<TARGET_FILE:${LIB_NAME}>)

# Create variable for the local build tree
get_property(libnabo_include_dirs DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
# Configure & generate config file for local build tree
configure_file(libnaboConfig.cmake.in
	"${PROJECT_BINARY_DIR}/libnaboConfig.cmake.conf" @ONLY)
file(GENERATE
	OUTPUT "${PROJECT_BINARY_DIR}/libnaboConfig.cmake"
	INPUT "${PROJECT_BINARY_DIR}/libnaboConfig.cmake.conf")

# 2- installation build #

# Change the library location for an install location
set(libnabo_library ${CMAKE_INSTALL_PREFIX}/lib/$<TARGET_FILE_NAME:${LIB_NAME}>)

# Change the include location for the case of an install location
set(libnabo_include_dirs ${CMAKE_INSTALL_PREFIX}/include)

# We put the generated file for installation in a different repository (i.e., ./CMakeFiles/)
configure_file(libnaboConfig.cmake.in
	"${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/libnaboConfig.cmake.conf" @ONLY)
file(GENERATE
	OUTPUT "${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/libnaboConfig.cmake"
	INPUT "${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/libnaboConfig.cmake.conf")

# The same versioning file can be used for both cases
configure_file(libnaboConfigVersion.cmake.in
	"${PROJECT_BINARY_DIR}/libnaboConfigVersion.cmake" @ONLY)

install(FILES
	"${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/libnaboConfig.cmake"
	"${PROJECT_BINARY_DIR}/libnaboConfigVersion.cmake"
	DESTINATION share/libnabo/cmake COMPONENT dev)


#=============================================
# Add uninstall target
#=============================================
if (NOT TARGET uninstall)
  configure_file(
	  "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
	  "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
	  IMMEDIATE @ONLY)

  add_custom_target(uninstall
	  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()
