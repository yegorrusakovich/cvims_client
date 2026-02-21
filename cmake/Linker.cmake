macro(cvims_client_configure_linker project_name)
  set(cvims_client_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(cvims_client_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE cvims_client_USER_LINKER_OPTION PROPERTY STRINGS ${cvims_client_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    cvims_client_USER_LINKER_OPTION_VALUES
    ${cvims_client_USER_LINKER_OPTION}
    cvims_client_USER_LINKER_OPTION_INDEX)

  if(${cvims_client_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${cvims_client_USER_LINKER_OPTION}', explicitly supported entries are ${cvims_client_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${cvims_client_USER_LINKER_OPTION}")
endmacro()
