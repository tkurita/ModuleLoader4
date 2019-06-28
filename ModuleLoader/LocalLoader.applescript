use scripting additions

property name : "LocalLoader"
property _idleTime : 0
property _idleInterval : 60 * 5
property _waitTime : _idleInterval
property _only_local : false
property _collecting : false

on load(a_name)
	tell make_loader()
		return load(a_name)
	end tell
end load

on set_localonly(flag)
	set my _only_local to flag
	return me
end set_localonly

on collecting_modules(a_flag)
	set my _collecting to a_flag
	return me
end collecting_modules


on current_location()
    set a_path to path to me
    if (POSIX path of a_path starts with "/private/var/folders/") then
        ¬
        error "This local loader applet does not allow to access own location. Recreate the local loader applet." number 1805
    end if
    tell application "Finder"
        set a_folder to container of a_path as alias
    end tell
    return a_folder
end current_location

on make_loader()
	tell script (get "ModuleLoader")
        resolve_module_finder()
		set_local(true)
		set_localonly(my _only_local)
		set_additional_paths({my current_location()})
		collecting_modules(my _collecting)
		return it
	end tell
end make_loader

on set_opts(opts)
	try
		set val to opts's only_local
		set_localonly(val)
	end try
	try
		set val to opts's collecting_modules
		collecting_modules(val)
	end try
	return me
end set_opts

on loader_with_opts(opts)
	return make_loader()'s set_opts(opts)
end loader_with_opts

on idle
	--ConsoleLog's do("start idle")
	if _idleTime is greater than or equal to _waitTime then
		--ConsoleLog's do("will quit")
		quit
		return 1
	end if
	set _idleTime to _idleTime + _idleInterval
	return _idleInterval
end idle

on quit
	--ConsoleLog's do("start quit")
	continue quit
	--ConsoleLog's do("did quit")
end quit

on run
	--return debug()
	set my _idleTime to 0
end run
