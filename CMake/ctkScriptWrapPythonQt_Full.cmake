###########################################################################
#
#  Library:   CTK
#
#  Copyright (c) Kitware Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0.txt
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################

#
# ctkScriptWrapPythonQt_Full
#

#
# Depends on:
#  CTK/CMake/ctkMacroWrapPythonQt.cmake
#

#
# This script should be invoked either as a CUSTOM_COMMAND
# or from the command line using the following syntax:
#
#    cmake -DWRAPPING_NAMESPACE:STRING=org.commontk -DTARGET:STRING=MyLib
#          -DSOURCES:STRING="file1^^file2" -DINCLUDE_DIRS:STRING=/path1:/path2
#          -DWRAP_INT_DIR:STRING=subir/subir/
#          -DPYTHONQTGENERATOR_EXECUTABLE:FILEPATH=/path/to/exec
#          -DOUTPUT_DIR:PATH=/path  -DQT_QMAKE_EXECUTABLE:PATH=/path/to/qt/qmake
#          -DHAS_DECORATOR:BOOL=True
#          -P ctkScriptWrapPythonQt_Full.cmake
#

if(NOT DEFINED CMAKE_CURRENT_LIST_DIR)
  get_filename_component(CMAKE_CURRENT_LIST_DIR ${CMAKE_CURRENT_LIST_FILE} PATH)
endif()
if(NOT DEFINED CMAKE_CURRENT_LIST_FILENAME)
  get_filename_component(CMAKE_CURRENT_LIST_FILENAME ${CMAKE_CURRENT_LIST_FILE} NAME)
endif()

# Check for non-defined var
foreach(var SOURCES TARGET INCLUDE_DIRS WRAP_INT_DIR WRAPPING_NAMESPACE HAS_DECORATOR)
  if(NOT DEFINED ${var})
    message(FATAL_ERROR "${var} not specified when calling ctkScriptWrapPythonQt")
  endif()
endforeach()

# Check for non-existing ${var}
foreach(var PYTHONQTGENERATOR_EXECUTABLE QT_QMAKE_EXECUTABLE OUTPUT_DIR)
  if(NOT EXISTS ${${var}})
    message(FATAL_ERROR "Failed to find ${var} when calling ctkScriptWrapPythonQt")
  endif()
endforeach()

# Convert wrapping namespace to subdir
string(REPLACE "." "_" WRAPPING_NAMESPACE_UNDERSCORE ${WRAPPING_NAMESPACE})

# Convert ^^ separated string to list
string(REPLACE "^^" ";" SOURCES "${SOURCES}")

foreach(FILE ${SOURCES})

  # what is the filename without the extension
  get_filename_component(TMP_FILENAME ${FILE} NAME_WE)

  set(includes
    "${includes}\n#include \"${TMP_FILENAME}.h\"")

  # Extract classname - NOTE: We assume the filename matches the associated class
  set(className ${TMP_FILENAME})
  #message(STATUS "FILE:${FILE}, className:${className}")

  set(objectTypes "${objectTypes}\n  <object-type name=\"${className}\"/>")

endforeach()

# Write master include file
  file(WRITE ${OUTPUT_DIR}/${WRAP_INT_DIR}ctkPythonQt_${TARGET}_masterinclude.h "
#ifndef __ctkPythonQt_${TARGET}_masterinclude_h
#define __ctkPythonQt_${TARGET}_masterinclude_h
${includes}
#endif
")

# Write Typesystem file
file(WRITE ${OUTPUT_DIR}/${WRAP_INT_DIR}typesystem_${TARGET}.xml "
<typesystem package=\"${WRAPPING_NAMESPACE}.${TARGET}\">
  ${objectTypes}
</typesystem>
")

# Extract PYTHONQTGENERATOR_DIR
get_filename_component(PYTHONQTGENERATOR_DIR ${PYTHONQTGENERATOR_EXECUTABLE} PATH)
#message(PYTHONQTGENERATOR_DIR:${PYTHONQTGENERATOR_DIR})

# Write Build file
file(WRITE ${OUTPUT_DIR}/${WRAP_INT_DIR}build_${TARGET}.txt "
<!-- File auto-generated by cmake macro ctkScriptWrapPythonQt_Full -->

<typesystem>
  <load-typesystem name=\"${PYTHONQTGENERATOR_DIR}/typesystem_core.xml\" generate=\"no\" />
  <load-typesystem name=\"${PYTHONQTGENERATOR_DIR}/typesystem_gui.xml\" generate=\"no\" />
  <load-typesystem name=\"${OUTPUT_DIR}/${WRAP_INT_DIR}/typesystem_${TARGET}.xml\" generate=\"yes\" />
</typesystem>
")

# Read include dirs from file
if(WIN32)
  if(NOT EXISTS ${INCLUDE_DIRS})
    message(FATAL_ERROR "On Windows, INCLUDE_DIRS should be the name of the file containing the include directories !")
  endif()
  file(READ ${INCLUDE_DIRS} INCLUDE_DIRS)
endif()

# Compute QTDIR
get_filename_component(QTDIR ${QT_QMAKE_EXECUTABLE}/../../ REALPATH)
set(ENV{QTDIR} ${QTDIR})

execute_process(
  COMMAND ${PYTHONQTGENERATOR_EXECUTABLE} --debug-level=sparse --include-paths=${INCLUDE_DIRS} --output-directory=${OUTPUT_DIR} ${OUTPUT_DIR}/${WRAP_INT_DIR}ctkPythonQt_${TARGET}_masterinclude.h ${OUTPUT_DIR}/${WRAP_INT_DIR}build_${TARGET}.txt
  WORKING_DIRECTORY ${PYTHONQTGENERATOR_DIR}
  RESULT_VARIABLE result
  #OUTPUT_VARIABLE output
  ERROR_VARIABLE error
  OUTPUT_QUIET
  )
#message(${error})
if(result)
  message(FATAL_ERROR "Failed to generate ${WRAPPING_NAMESPACE_UNDERSCORE}_${TARGET}_init.cpp\n${error}")
endif()

# Configure 'ctkMacroWrapPythonQtModuleInit.cpp.in' replacing TARGET and
# WRAPPING_NAMESPACE_UNDERSCORE.
configure_file(
  ${CMAKE_CURRENT_LIST_DIR}/ctkMacroWrapPythonQtModuleInit.cpp.in
  ${OUTPUT_DIR}/${WRAP_INT_DIR}${WRAPPING_NAMESPACE_UNDERSCORE}_${TARGET}_module_init.cpp
  )

# Since PythonQtGenerator or file(WRITE ) doesn't 'update the timestamp - Let's touch the files
execute_process(
  COMMAND ${CMAKE_COMMAND} -E touch
    ${OUTPUT_DIR}/${WRAP_INT_DIR}${WRAPPING_NAMESPACE_UNDERSCORE}_${TARGET}_init.cpp
    ${OUTPUT_DIR}/${WRAP_INT_DIR}ctkPythonQt_${TARGET}_masterinclude.h
  )
