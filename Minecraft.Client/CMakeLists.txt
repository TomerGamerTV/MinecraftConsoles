include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/Common.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/Durango.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/ORBIS.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/PS3.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/PSVita.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/Windows.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/Xbox360.cmake")

# Apple platform source list
if(APPLE)
  include("${CMAKE_CURRENT_LIST_DIR}/cmake/sources/Apple.cmake")
endif()

include("${CMAKE_SOURCE_DIR}/cmake/CommonSources.cmake")

if(NOT APPLE)
  include("${CMAKE_SOURCE_DIR}/cmake/Utils.cmake")
endif()

# Combine all source files into a single variable for the target
# We cant use CMAKE_CONFIGURE_PRESET here as VS doesn't set it, so just rely on the folder
set(MINECRAFT_CLIENT_SOURCES
  ${MINECRAFT_CLIENT_COMMON}
  $<$<STREQUAL:${PLATFORM_NAME},Durango>:${MINECRAFT_CLIENT_DURANGO}>
  $<$<STREQUAL:${PLATFORM_NAME},Orbis>:${MINECRAFT_CLIENT_ORBIS}>
  $<$<STREQUAL:${PLATFORM_NAME},PS3>:${MINECRAFT_CLIENT_PS3}>
  $<$<STREQUAL:${PLATFORM_NAME},PSVita>:${MINECRAFT_CLIENT_PSVITA}>
  $<$<STREQUAL:${PLATFORM_NAME},Windows64>:${MINECRAFT_CLIENT_WINDOWS}>
  $<$<STREQUAL:${PLATFORM_NAME},Xbox>:${MINECRAFT_CLIENT_XBOX360}>
  ${SOURCES_COMMON}
)

# Apple uses a separate variable since generator expressions can't handle OR
if(APPLE)
  list(APPEND MINECRAFT_CLIENT_SOURCES ${MINECRAFT_CLIENT_APPLE})
endif()

if(PLATFORM_NAME STREQUAL "iOS")
  # iOS: build as app bundle
  add_executable(Minecraft.Client MACOSX_BUNDLE ${MINECRAFT_CLIENT_SOURCES})
  set_target_properties(Minecraft.Client PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/iOS/Info.plist"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.lce.minecraft-console"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "-"
    RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/iOS/LaunchScreen.storyboard"
  )
elseif(PLATFORM_NAME STREQUAL "macOS")
  # macOS: build as app bundle
  add_executable(Minecraft.Client MACOSX_BUNDLE ${MINECRAFT_CLIENT_SOURCES})
  set_target_properties(Minecraft.Client PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/macOS/Info.plist"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.lce.minecraft-console"
    MACOSX_BUNDLE_BUNDLE_NAME "Minecraft LCE"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.lce.minecraft-console"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "-"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
  )
else()
  add_executable(Minecraft.Client ${MINECRAFT_CLIENT_SOURCES})
endif()

# Only define executable on windows
if(PLATFORM_NAME STREQUAL "Windows64")
  set_target_properties(Minecraft.Client PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

target_include_directories(Minecraft.Client PRIVATE
  "${CMAKE_BINARY_DIR}/generated/" # This is for the generated BuildVer.h
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_SOURCE_DIR}/include/"
)

# Platform-specific include directories
if(APPLE)
  target_include_directories(Minecraft.Client PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/Apple/Iggy/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/Apple"
    "${CMAKE_CURRENT_SOURCE_DIR}/Apple/4JLibs/inc"
    "${CMAKE_CURRENT_SOURCE_DIR}/Apple/Input"
  )
else()
  target_include_directories(Minecraft.Client PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/Iggy/include"
  )
endif()

target_compile_definitions(Minecraft.Client PRIVATE
  ${MINECRAFT_SHARED_DEFINES}
)

# Precompiled headers - Apple uses a different stdafx approach
if(NOT APPLE)
  target_precompile_headers(Minecraft.Client PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:stdafx.h>")
  set_source_files_properties(compat_shims.cpp PROPERTIES SKIP_PRECOMPILE_HEADERS ON)
endif()

configure_compiler_target(Minecraft.Client)

set_target_properties(Minecraft.Client PROPERTIES
  OUTPUT_NAME "Minecraft.Client"
)

if(NOT APPLE)
  set_target_properties(Minecraft.Client PROPERTIES
    VS_DEBUGGER_WORKING_DIRECTORY "$<TARGET_FILE_DIR:Minecraft.Client>"
  )
endif()

# Platform-specific linking
if(APPLE)
  # Apple frameworks
  find_library(METAL_FRAMEWORK Metal REQUIRED)
  find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
  find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)
  find_library(GAMECONTROLLER_FRAMEWORK GameController REQUIRED)
  find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
  find_library(AUDIOTOOLBOX_FRAMEWORK AudioToolbox REQUIRED)
  find_library(COREAUDIO_FRAMEWORK CoreAudio REQUIRED)
  find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
  find_library(AVFOUNDATION_FRAMEWORK AVFoundation REQUIRED)
  find_library(IMAGEIO_FRAMEWORK ImageIO REQUIRED)

  target_link_libraries(Minecraft.Client PRIVATE
    Minecraft.World
    ${METAL_FRAMEWORK}
    ${METALKIT_FRAMEWORK}
    ${QUARTZCORE_FRAMEWORK}
    ${GAMECONTROLLER_FRAMEWORK}
    ${COREGRAPHICS_FRAMEWORK}
    ${AUDIOTOOLBOX_FRAMEWORK}
    ${COREAUDIO_FRAMEWORK}
    ${FOUNDATION_FRAMEWORK}
    ${AVFOUNDATION_FRAMEWORK}
    ${IMAGEIO_FRAMEWORK}
  )

  if(PLATFORM_NAME STREQUAL "macOS")
    find_library(APPKIT_FRAMEWORK AppKit REQUIRED)
    find_library(IOKIT_FRAMEWORK IOKit REQUIRED)
    target_link_libraries(Minecraft.Client PRIVATE
      ${APPKIT_FRAMEWORK}
      ${IOKIT_FRAMEWORK}
    )
  elseif(PLATFORM_NAME STREQUAL "iOS")
    find_library(UIKIT_FRAMEWORK UIKit REQUIRED)
    target_link_libraries(Minecraft.Client PRIVATE
      ${UIKIT_FRAMEWORK}
    )
  endif()

  # Metal shader compilation
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Apple/Metal/MetalShaders.metal")
    set(METAL_SHADER_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/Apple/Metal/MetalShaders.metal")
    set(METAL_SHADER_OUTPUT "$<TARGET_FILE_DIR:Minecraft.Client>/default.metallib")

    if(PLATFORM_NAME STREQUAL "iOS")
      set(METAL_SDK "iphoneos")
      set(METAL_MIN_VERSION "-mios-version-min=15.0")
    else()
      set(METAL_SDK "macosx")
      set(METAL_MIN_VERSION "-mmacosx-version-min=13.0")
    endif()

    add_custom_command(TARGET Minecraft.Client POST_BUILD
      COMMAND xcrun -sdk ${METAL_SDK} metal ${METAL_MIN_VERSION} -c "${METAL_SHADER_SOURCE}" -o "${CMAKE_CURRENT_BINARY_DIR}/MetalShaders.air"
      COMMAND xcrun -sdk ${METAL_SDK} metallib "${CMAKE_CURRENT_BINARY_DIR}/MetalShaders.air" -o "${METAL_SHADER_OUTPUT}"
      COMMENT "Compiling Metal shaders..."
      VERBATIM
    )
  endif()
else()
  # Windows linking
  target_link_libraries(Minecraft.Client PRIVATE
    Minecraft.World
    d3d11
    d3dcompiler
    XInput9_1_0
    wsock32
    legacy_stdio_definitions
    $<$<CONFIG:Debug>: # Debug 4J libraries
      "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/4JLibs/libs/4J_Input_d.lib"
      "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/4JLibs/libs/4J_Storage_d.lib"
      "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/4JLibs/libs/4J_Render_PC_d.lib"
    >
    $<$<NOT:$<CONFIG:Debug>>: # Release 4J libraries
      "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/4JLibs/libs/4J_Input.lib"
      "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/4JLibs/libs/4J_Storage.lib"
      "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/4JLibs/libs/4J_Render_PC.lib"
    >
  )

  # Iggy libs (Windows only - Apple uses stubs)
  foreach(lib IN LISTS IGGY_LIBS)
    target_link_libraries(Minecraft.Client PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}/Iggy/lib/${lib}")
  endforeach()
endif()

# ---
# Asset / redist copy
# ---
include("${CMAKE_SOURCE_DIR}/cmake/CopyAssets.cmake")
set(ASSET_FOLDER_PAIRS
  "${CMAKE_CURRENT_SOURCE_DIR}/music"                  "music"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/Media"           "Common/Media"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/res"             "Common/res"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/Trial"           "Common/Trial"
  "${CMAKE_CURRENT_SOURCE_DIR}/Common/Tutorial"        "Common/Tutorial"
)

# Platform-specific media folder
if(APPLE)
  # Apple shares Windows64Media for now (same arc format)
  list(APPEND ASSET_FOLDER_PAIRS
    "${CMAKE_CURRENT_SOURCE_DIR}/Windows64Media"  "Windows64Media"
  )
else()
  list(APPEND ASSET_FOLDER_PAIRS
    "${CMAKE_CURRENT_SOURCE_DIR}/${PLATFORM_NAME}Media"  "${PLATFORM_NAME}Media"
  )
endif()

setup_asset_folder_copy(Minecraft.Client "${ASSET_FOLDER_PAIRS}")

if(NOT APPLE)
  # Copy redist files (Windows only - Iggy DLLs)
  add_copyredist_target(Minecraft.Client)
endif()

# Make sure GameHDD exists on Windows
if(PLATFORM_NAME STREQUAL "Windows64")
  add_gamehdd_target(Minecraft.Client)
endif()
