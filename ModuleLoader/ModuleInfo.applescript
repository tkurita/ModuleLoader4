on set_setupped(bool)
	set my _setupped to bool
end set_setupped

on is_setupped()
	return my _setupped
end is_setupped

on need_setup()
	return not my _setupped
end need_setup

on dependencies()
	return my _dependecies
end dependencies

on module_script()
	return my _script
end module_script

on set_module_script(a_script)
	set my _script to a_script
	return me
end set_module_script

on module_version()
	return my _version
end module_version

on has_module_loaded()
    return my _has_module_loaded
end

on make_with_loadinfo(loadinfo)
	--using terms from application "ModuleFinder"
		return make_with_vars(loadinfo's script, loadinfo's dependency info, loadinfo's version, loadinfo's has module loaded, false)
	--end using terms from
end make_with_loadinfo

on make_with_vars(a_script, dependencies_list, a_version, has_module_loaded, setupped_flag)
	script ModuleInfo
		property _script : a_script
		property _dependecies : dependencies_list
		property _version : a_version
        property _has_module_loaded : has_module_loaded
		property _setupped : setupped_flag
	end script
end make_with_vars

return me
