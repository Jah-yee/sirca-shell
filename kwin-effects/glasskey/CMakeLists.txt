# Glass Key: a second, small KWin effect (see glasskey.h). Built with the Glass effect; installed under its own name.
set(glasskey_SOURCES glasskey.cpp main.cpp glasskey.qrc)
add_library(glasskey MODULE ${glasskey_SOURCES})
target_link_libraries(glasskey PRIVATE Qt6::Core Qt6::Gui KF6::ConfigCore KF6::ConfigGui KWin::kwin)
install(TARGETS glasskey DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins)
if(GLASS_KWIN_67)
    target_compile_definitions(glasskey PRIVATE GLASS_KWIN_67)
endif()
