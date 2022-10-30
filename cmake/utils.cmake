function(nabo_generate_version_header)
  set(MINOR_VERSION_STR ${CMAKE_PROJECT_VERSION_MINOR})
  string(LENGTH "${MINOR_VERSION_STR}" MINOR_VERSION_STR_LEN)
  if(MINOR_VERSION_STR_LEN LESS 2)
    string(PREPEND MINOR_VERSION_STR "0")
  endif()

  set(PATCH_VERSION_STR ${CMAKE_PROJECT_VERSION_PATCH})
  string(LENGTH "${PATCH_VERSION_STR}" PATCH_VERSION_STR_LEN)
  if(PATCH_VERSION_STR_LEN LESS 2)
    string(PREPEND PATCH_VERSION_STR "0")
  endif()

  string(CONCAT NABO_VERSION_INT 
    ${CMAKE_PROJECT_VERSION_MAJOR}
    ${MINOR_VERSION_STR}
    ${PATCH_VERSION_STR})
  configure_file(${PROJECT_SOURCE_DIR}/cmake/nabo_version.h.in 
                 include/nabo_version.h)
endfunction()