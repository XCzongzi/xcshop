if(NOT EXISTS "${KITS_SOURCE}")
    return()
endif()
# Match the public Alpha directories and file types allowed by .gitignore.
file(GLOB kit_files LIST_DIRECTORIES false RELATIVE "${KITS_SOURCE}"
    "${KITS_SOURCE}/blueprints/alpha-r0/*.xcshoper"
    "${KITS_SOURCE}/blueprints/alpha-r1/*.xcshoper"
    "${KITS_SOURCE}/materials/alpha-r0-26.3/*.xcontent"
    "${KITS_SOURCE}/materials/alpha-r0-26.3/*.xclist"
    "${KITS_SOURCE}/materials/alpha-r1-1.21.5-26.2/*.xcontent"
    "${KITS_SOURCE}/materials/alpha-r1-1.21.5-26.2/*.xclist")
list(APPEND kit_files "alpha-r0-README.md" "templates/alpha-r0.xcshopT"
    "alpha-r1-README.md" "templates/alpha-r1.xcshopT")
foreach(relative IN LISTS kit_files)
    if(NOT EXISTS "${KITS_TARGET}/${relative}")
        get_filename_component(parent "${KITS_TARGET}/${relative}" DIRECTORY)
        file(MAKE_DIRECTORY "${parent}")
        configure_file("${KITS_SOURCE}/${relative}" "${KITS_TARGET}/${relative}" COPYONLY)
    endif()
endforeach()
