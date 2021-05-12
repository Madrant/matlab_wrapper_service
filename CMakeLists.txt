# Check minimum required CMake version
cmake_minimum_required(VERSION 3.0)

# Set project name (package name, source archive name)
project("model")

# Set script name
set(PROJECT_NAME "model")

# Check cmake directories
message("Source dir: ${CMAKE_SOURCE_DIR}")
message("Binary dir: ${CMAKE_BINARY_DIR}")

if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    message(FATAL_ERROR "cmake in-source build are not allowed - please call cmake from 'build' directory")
endif()

# Install section (make install):
install(
    FILES service.py
    DESTINATION /opt/${PROJECT_NAME}
    RENAME ${PROJECT_NAME}.py
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ
)

install(
    FILES model_call.py
    DESTINATION /opt/${PROJECT_NAME}
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ
)

install(
    FILES model.py messages.py udp_listener.py
    DESTINATION /opt/${PROJECT_NAME}
    PERMISSIONS OWNER_WRITE OWNER_READ GROUP_READ WORLD_READ
)

install(
    FILES out/libmodel.so
    DESTINATION /opt/${PROJECT_NAME}
    PERMISSIONS OWNER_WRITE OWNER_READ GROUP_READ WORLD_READ
)

set(INIT_TYPE "systemd") # systemd, sysv

if(INIT_TYPE STREQUAL "sysv")
install(
    FILES files/init
    DESTINATION /etc/init.d/
    RENAME ${PROJECT_NAME}
    PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ
)
else()
install(
    FILES files/systemd
    DESTINATION /etc/systemd/system
    RENAME ${PROJECT_NAME}.service
    PERMISSIONS OWNER_WRITE OWNER_READ GROUP_READ WORLD_READ
)
endif()

install(
    FILES files/logrotate
    DESTINATION /etc/logrotate.d
    RENAME ${PROJECT_NAME}
    PERMISSIONS OWNER_WRITE OWNER_READ GROUP_READ WORLD_READ
)

# Packaging (make package, make package_source)
set(CPACK_GENERATOR "DEB")

set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Maintainer") #required

set(CPACK_PACKAGE_VERSION 1.0.0)
set(CPACK_PACKAGE_VERSION_MAJOR 1)
set(CPACK_PACKAGE_VERSION_MINOR 0)
set(CPACK_PACKAGE_VERSION_PATCH 0)

set(CPACK_DEBIAN_FILE_NAME "${PROJECT_NAME}-${CPACK_PACKAGE_VERSION}.deb")

set(CPACK_DEBIAN_PACKAGE_DEPENDS "python3")

include(CPack)
