include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(cvims_client_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(cvims_client_setup_options)
  option(cvims_client_ENABLE_HARDENING "Enable hardening" ON)
  option(cvims_client_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cvims_client_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cvims_client_ENABLE_HARDENING
    OFF)

  cvims_client_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cvims_client_PACKAGING_MAINTAINER_MODE)
    option(cvims_client_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cvims_client_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cvims_client_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cvims_client_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cvims_client_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cvims_client_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cvims_client_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cvims_client_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cvims_client_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cvims_client_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cvims_client_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cvims_client_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cvims_client_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cvims_client_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cvims_client_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cvims_client_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cvims_client_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cvims_client_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cvims_client_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cvims_client_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cvims_client_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cvims_client_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cvims_client_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cvims_client_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cvims_client_ENABLE_IPO
      cvims_client_WARNINGS_AS_ERRORS
      cvims_client_ENABLE_SANITIZER_ADDRESS
      cvims_client_ENABLE_SANITIZER_LEAK
      cvims_client_ENABLE_SANITIZER_UNDEFINED
      cvims_client_ENABLE_SANITIZER_THREAD
      cvims_client_ENABLE_SANITIZER_MEMORY
      cvims_client_ENABLE_UNITY_BUILD
      cvims_client_ENABLE_CLANG_TIDY
      cvims_client_ENABLE_CPPCHECK
      cvims_client_ENABLE_COVERAGE
      cvims_client_ENABLE_PCH
      cvims_client_ENABLE_CACHE)
  endif()

  cvims_client_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cvims_client_ENABLE_SANITIZER_ADDRESS OR cvims_client_ENABLE_SANITIZER_THREAD OR cvims_client_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cvims_client_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cvims_client_global_options)
  if(cvims_client_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cvims_client_enable_ipo()
  endif()

  cvims_client_supports_sanitizers()

  if(cvims_client_ENABLE_HARDENING AND cvims_client_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cvims_client_ENABLE_SANITIZER_UNDEFINED
       OR cvims_client_ENABLE_SANITIZER_ADDRESS
       OR cvims_client_ENABLE_SANITIZER_THREAD
       OR cvims_client_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cvims_client_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cvims_client_ENABLE_SANITIZER_UNDEFINED}")
    cvims_client_enable_hardening(cvims_client_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cvims_client_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cvims_client_warnings INTERFACE)
  add_library(cvims_client_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cvims_client_set_project_warnings(
    cvims_client_warnings
    ${cvims_client_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    cvims_client_enable_sanitizers(
      cvims_client_options
      ${cvims_client_ENABLE_SANITIZER_ADDRESS}
      ${cvims_client_ENABLE_SANITIZER_LEAK}
      ${cvims_client_ENABLE_SANITIZER_UNDEFINED}
      ${cvims_client_ENABLE_SANITIZER_THREAD}
      ${cvims_client_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(cvims_client_options PROPERTIES UNITY_BUILD ${cvims_client_ENABLE_UNITY_BUILD})

  if(cvims_client_ENABLE_PCH)
    target_precompile_headers(
      cvims_client_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cvims_client_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cvims_client_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cvims_client_ENABLE_CLANG_TIDY)
    cvims_client_enable_clang_tidy(cvims_client_options ${cvims_client_WARNINGS_AS_ERRORS})
  endif()

  if(cvims_client_ENABLE_CPPCHECK)
    cvims_client_enable_cppcheck(${cvims_client_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cvims_client_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cvims_client_enable_coverage(cvims_client_options)
  endif()

  if(cvims_client_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cvims_client_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cvims_client_ENABLE_HARDENING AND NOT cvims_client_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cvims_client_ENABLE_SANITIZER_UNDEFINED
       OR cvims_client_ENABLE_SANITIZER_ADDRESS
       OR cvims_client_ENABLE_SANITIZER_THREAD
       OR cvims_client_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cvims_client_enable_hardening(cvims_client_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
