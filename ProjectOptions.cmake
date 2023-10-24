include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(subreddit_analyzer_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(subreddit_analyzer_setup_options)
  option(subreddit_analyzer_ENABLE_HARDENING "Enable hardening" ON)
  option(subreddit_analyzer_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    subreddit_analyzer_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    subreddit_analyzer_ENABLE_HARDENING
    OFF)

  subreddit_analyzer_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR subreddit_analyzer_PACKAGING_MAINTAINER_MODE)
    option(subreddit_analyzer_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(subreddit_analyzer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(subreddit_analyzer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(subreddit_analyzer_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(subreddit_analyzer_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(subreddit_analyzer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(subreddit_analyzer_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(subreddit_analyzer_ENABLE_IPO "Enable IPO/LTO" ON)
    option(subreddit_analyzer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(subreddit_analyzer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(subreddit_analyzer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(subreddit_analyzer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(subreddit_analyzer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(subreddit_analyzer_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(subreddit_analyzer_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(subreddit_analyzer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(subreddit_analyzer_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      subreddit_analyzer_ENABLE_IPO
      subreddit_analyzer_WARNINGS_AS_ERRORS
      subreddit_analyzer_ENABLE_USER_LINKER
      subreddit_analyzer_ENABLE_SANITIZER_ADDRESS
      subreddit_analyzer_ENABLE_SANITIZER_LEAK
      subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED
      subreddit_analyzer_ENABLE_SANITIZER_THREAD
      subreddit_analyzer_ENABLE_SANITIZER_MEMORY
      subreddit_analyzer_ENABLE_UNITY_BUILD
      subreddit_analyzer_ENABLE_CLANG_TIDY
      subreddit_analyzer_ENABLE_CPPCHECK
      subreddit_analyzer_ENABLE_COVERAGE
      subreddit_analyzer_ENABLE_PCH
      subreddit_analyzer_ENABLE_CACHE)
  endif()

  subreddit_analyzer_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (subreddit_analyzer_ENABLE_SANITIZER_ADDRESS OR subreddit_analyzer_ENABLE_SANITIZER_THREAD OR subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(subreddit_analyzer_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(subreddit_analyzer_global_options)
  if(subreddit_analyzer_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    subreddit_analyzer_enable_ipo()
  endif()

  subreddit_analyzer_supports_sanitizers()

  if(subreddit_analyzer_ENABLE_HARDENING AND subreddit_analyzer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED
       OR subreddit_analyzer_ENABLE_SANITIZER_ADDRESS
       OR subreddit_analyzer_ENABLE_SANITIZER_THREAD
       OR subreddit_analyzer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${subreddit_analyzer_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED}")
    subreddit_analyzer_enable_hardening(subreddit_analyzer_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(subreddit_analyzer_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(subreddit_analyzer_warnings INTERFACE)
  add_library(subreddit_analyzer_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  subreddit_analyzer_set_project_warnings(
    subreddit_analyzer_warnings
    ${subreddit_analyzer_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(subreddit_analyzer_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(subreddit_analyzer_options)
  endif()

  include(cmake/Sanitizers.cmake)
  subreddit_analyzer_enable_sanitizers(
    subreddit_analyzer_options
    ${subreddit_analyzer_ENABLE_SANITIZER_ADDRESS}
    ${subreddit_analyzer_ENABLE_SANITIZER_LEAK}
    ${subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED}
    ${subreddit_analyzer_ENABLE_SANITIZER_THREAD}
    ${subreddit_analyzer_ENABLE_SANITIZER_MEMORY})

  set_target_properties(subreddit_analyzer_options PROPERTIES UNITY_BUILD ${subreddit_analyzer_ENABLE_UNITY_BUILD})

  if(subreddit_analyzer_ENABLE_PCH)
    target_precompile_headers(
      subreddit_analyzer_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(subreddit_analyzer_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    subreddit_analyzer_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(subreddit_analyzer_ENABLE_CLANG_TIDY)
    subreddit_analyzer_enable_clang_tidy(subreddit_analyzer_options ${subreddit_analyzer_WARNINGS_AS_ERRORS})
  endif()

  if(subreddit_analyzer_ENABLE_CPPCHECK)
    subreddit_analyzer_enable_cppcheck(${subreddit_analyzer_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(subreddit_analyzer_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    subreddit_analyzer_enable_coverage(subreddit_analyzer_options)
  endif()

  if(subreddit_analyzer_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(subreddit_analyzer_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(subreddit_analyzer_ENABLE_HARDENING AND NOT subreddit_analyzer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR subreddit_analyzer_ENABLE_SANITIZER_UNDEFINED
       OR subreddit_analyzer_ENABLE_SANITIZER_ADDRESS
       OR subreddit_analyzer_ENABLE_SANITIZER_THREAD
       OR subreddit_analyzer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    subreddit_analyzer_enable_hardening(subreddit_analyzer_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
