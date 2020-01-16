(* Copyright (C) 2019 Kurita Tetsuro
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 Foobar is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with Foobar.  If not, see <http://www.gnu.org/licenses/> *)

(*!@references
Home page || https://www.script-factory.net/XModules/ModuleLoadee/en/index.html
ChangeLog || https://www.script-factory.net/XModules/ModuleLoader/changelog.html
Repository || https://github.com/tkurita/ModuleLoader4
  
@title ModuleLoader Reference
* Version 4.0
* Author Kurita Tetsuro ((<scriptfactory@mac.com>))
* Requirements : OS X 10.9 or later
* ((<Home page>)) || ((<ChangeLog>)) || ((<Repository>))

ModuleLoader is a module loading system for AppleScript.
*)
use scripting additions

property name : "LoaderProxy"

on import(a_name)
	set pwd to system attribute "INPUT_FILE_DIR"
	-- set pwd to "/Users/tkurita/Dev/Projects/ModuleLoader4/ModuleLoader4/ModuleLoader"
	return run script POSIX file (pwd & "/" & a_name & ".applescript")
end import

property FastList : import("FastList")
property ModuleCache : import("ModuleCache")'s initialize()
property ConsoleLog : import("ConsoleLog")
property PropertyAccessor : import("PropertyAccessor")'s initialize()
property ModuleInfo : import("ModuleInfo")

property _loadonly : false
property _module_cache : missing value
--property _logger : ConsoleLog's make_with("ModuleLoader")'s start_log()
property _logger : missing value
property _module_finder : missing value
property _exported : {}
 
(** Properties for local loader **)
property _is_local : false
property _additional_paths : {}
property _collecting : false
property _only_local : false

 
on has_module_loaded_by(a_script)
    try
        -- without coercing type value into text,
        -- always false.
        return a_script's module_loaded_by's class as text is "handler"
    end try
    return false
end had_module_loaded_by
 
on setup_script(a_moduleinfo)
	set a_script to a_moduleinfo's module_script()
	-- log ("start setup_script" & " for " & name of a_script)
	a_moduleinfo's set_setupped(true)
	resolve_dependencies(a_moduleinfo, false)
    --log "after resolve_dependencies in setup_script"
    if has_module_loaded_by(a_script) then
        set a_script to a_script's module_loaded_by(me)
        a_moduleinfo's set_module_script(a_script)
    (*
    -- don't support old module loaded event
    -- to avoid error "内部の表があふれました。" number -2707
    else
        try -- to keep compatibility with ModuleLoader.osax
            --log "before module loaded : " & (name of a_script)
            --using terms from application "ModuleFinder"
                set a_script to module loaded a_script by me
            --end using terms from
            a_moduleinfo's set_module_script(a_script)
        on error msg number errno
            -- 1800 : the module is not found
            -- -1708 : handelr "module_loaded_by" is not implemented
            if errno is not -1708 then
                error msg number errno
            end if
        end try
    *)
    end if
	trim_required_import_items(a_script)
	-- log "end setup_script"
end setup_script

on trim_required_import_items(a_script)
	try
		set reqimport_items to required import items of a_script
		if (count reqimport_items) is 0 then
			return
		end if
	on error
		return
	end try
	
	set reduced_import_items to {}
	repeat with an_item in reqimport_items
		set is_scpt to false
		try
			set is_scpt to ((class of item of an_item) is script)
		end try
		if not is_scpt then
			set end of reduced_import_items to (contents of an_item)
		end if
	end repeat
	set required import items of a_script to reduced_import_items
end trim_required_import_items

on raise_error(a_name, a_location)
	set folder_path to quoted form of (a_location as text)
	error a_name & " is not found in " & folder_path number 1800
end raise_error

on do_log(msg)
	if my _logger is not missing value then
		my _logger's do(msg)
	end if
end do_log

on export_to_cache(a_name, a_script)
    --log "start export_to_cache"
    tell application (my _module_finder)
        --using terms from application "ModuleFinder"
            set dependencies to extract dependencies for a_script
        --end using terms from
    end tell
	set a_moduleinfo to ModuleInfo's make_with_vars(a_script, dependencies, missing value, false)
    my _module_cache's add_module(a_name, missing value, a_moduleinfo)
    setup_script(a_moduleinfo)
    return me
end export_to_cache

on load_module(mspec) -- private
	--log "start load_module"
	--log mspec
	set force_reload to false
	set a_class to class of mspec
	set required_version to missing value
	if a_class is in {record, module specifier} then
		set a_name to mspec's name
		try
			set force_reload to reloading of mspec
        on error
            try
                set force_reload to |reloading| of mspec
            end try
		end try
		try
			set required_version to mspec's version
		end try
	else if a_class is list then
		set a_name to item 1 of mspec
		try
			set force_reload to reloading of item 2 of mspec
		end try
	else
		set a_name to mspec
	end if
	
	if a_name is in {":", "", "/", "."} then
		error (quoted form of mspec's name) & " is invald form to specify a module." number 1801
	end if
	
	--log "force_reload : " & force_reload
	if not force_reload then

        if required_version is missing value then
            set a_moduleinfo to my _module_cache's module_for_name(a_name)
        else
            set a_moduleinfo to my _module_cache's module_for_name_version(a_name, required_version)
        end if
        if a_moduleinfo is not missing value then
			set has_exported to true
            --log "end load_module with has_exported"
            return a_moduleinfo
        else
			set has_exported to false
		end if
	end if
	
	set adpaths to my _additional_paths
	
	if my _collecting or my _only_local then
		try
			tell application (my _module_finder)
				--using terms from application "ModuleFinder"
					set a_loadinfo to load module mspec additional paths adpaths without other paths
				--end using terms from
			end tell
		on error msg number errno
			if my _collecting then
				set a_loadinfo to try_collect(mspec, adpaths)
			else
				error msg number errno
			end if
		end try
	else
		tell application _module_finder
			--using terms from application "ModuleFinder"
				set a_loadinfo to load module mspec additional paths adpaths
			--end using terms from
		end tell
	end if
	-- log "after load module"
	
	set a_path to file of a_loadinfo
	-- log "file of a_loadinfo :" &(a_path as text)
	if force_reload then
		set a_moduleinfo to ModuleInfo's make_with_loadinfo(a_loadinfo)
		my _module_cache's replace_module(a_name, a_path, a_moduleinfo)
	else
        set a_moduleinfo to my _module_cache's module_for_path(a_path)
        if a_moduleinfo is missing value then
			set a_moduleinfo to ModuleInfo's make_with_loadinfo(a_loadinfo)
		end if
        my _module_cache's add_module(a_name, a_path, a_moduleinfo)
	end if
	--log "end of load_module"
	return a_moduleinfo
end load_module

on resolve_dependencies(a_moduleinfo)
	--log "start resolve dependencies"
	repeat with a_dep in a_moduleinfo's dependencies()
		set an_accessor to PropertyAccessor's make_with_name(name of a_dep)
        --using terms from application "ModuleFinder"
            set dep_moduleinfo to load_module(module specifier of a_dep)
        --end using terms from
		if dep_moduleinfo's need_setup() then
			setup_script(dep_moduleinfo)
		end if
		an_accessor's set_value(a_moduleinfo's module_script(), dep_moduleinfo's module_script())
	end repeat
	--log "end resolve dependencies"
end resolve_dependencies

on resolve_module_finder()
    -- log "start resolve_module_finder"
	if my _module_finder is missing value then
		set my _module_finder to (path to resource "ModuleFinder.app") as text
        ModuleCache's set_module_finder(my _module_finder)
	end if
    -- log "end resolve_module_finder"
end resolve_module_finder

(*!@group Loading Libraries *)
 
(*!@abstruct Load predefined libraries.
@param a_script(script) : a script object to setup predefined libraries.
@result missing value
*)
on setup(a_script)
	global __module_dependencies__
    resolve_module_finder()
    set my _module_cache to make ModuleCache
    if (length of my _exported > 0) then
        repeat with x in my _exported
            export_to_cache(name of x, x)
        end repeat
    end if
 	
	-- options for local loader
	if my _is_local then
		try
			if class of _collecting_modules_ of a_script is boolean then -- avoid problem in osacompile Mac OS X 10.6
				set my _collecting to _collecting_modules_ of a_script
			end if
		on error
			try -- compatibility with ModuleLoader.osax
				--using terms from application "ModuleFinder"
					if class of collecting modules of a_script is boolean then
						set my _collecting to collecting modules of a_script
					end if
				--end using terms from
			end try
		end try
		
		try
			if class of _only_local_ of a_script is boolean then -- avoid problem in osacompile Mac OS X 10.6
				set my _only_local to _only_local_ of a_script
			end if
		on error
			try -- compatibility with ModuleLoader.osax
				--using terms from application "ModuleFinder"
					if class of only local of a_script is boolean then
						set my _only_local to only local of a_script
					end if
				--end using terms from
			end try
		end try
	end if
	
	try
		set dependencies to __module_dependencies__
		--log "found __module_dependencies__"
	on error
		tell application (my _module_finder)
			--using terms from application "ModuleFinder"
				set dependencies to extract dependencies for a_script
			--end using terms from
		end tell
		--log "not found __module_dependencies__"
	end try
	--log dependencies
	repeat with a_dep in dependencies
		--log name of a_dep
		--using terms from application "ModuleFinder"
			set a_moduleinfo to load_module(module specifier of a_dep)
		--end using terms from
		set an_accessor to PropertyAccessor's make_with_name(name of a_dep)
		if a_moduleinfo's need_setup() then
			setup_script(a_moduleinfo)
		end if
		an_accessor's set_value(a_script, a_moduleinfo's module_script())
	end repeat
	
    if has_module_loaded_by(a_script) then
        a_script's module_loaded_by(me)
    end if

	--log "will set __module_dependencies__"
	set __module_dependencies__ to dependencies
	trim_required_import_items(a_script)
	return missing value
end setup

(*!@abstruct Load a library.
@description
Pass a text or a record as a specifier of a library.
The text should be a name of the library.
The record can contain "version" and "reloading" labels.
 
You can use the "version" label to specify the verion of the library to be loaded.
 
The "reloading" label of true value cause to force reload the library.
 
@param module_specifier (record or text) : a specifier to a library.
@result script
@example
tell script "ModuleLoader"
    load("SimpleTextLib")
    load({name:"SimpleTextLib", version:"1.5", reloading:true})
end tell
*)
on load(module_specifier) -- it is unknown to make this handler public. keep private and undocumented.
    -- log "start load"
     resolve_module_finder()
     if my _module_cache is missing value then
         set my _module_cache to make ModuleCache
     end if
     set a_moduleinfo to load_module(module_specifier)
     -- log "after load_module in load"
     if a_moduleinfo's need_setup() then
         if not my _loadonly then
             setup_script(a_moduleinfo)
         end if
     end if
    --  log "end of load"
     return a_moduleinfo's module_script()
 end load
 
(*!@group Mapipulating Paths *)

(*!@abstruct Obtain location to search for libraries.
@result list
@example
script "ModuleLoader"'s module_paths()
-- {"/Users/yourhome/Library/Scripts/Modules", "/Users/yourhome/Library/Script Libraries", "/Library/Scripts/Modules", "/Library/Script Libraries", "/Network/Library/Scripts/Modules", "/Network/Library/Script Libraries"}
*)
on module_paths()
     resolve_module_finder()
     tell application _module_finder
         --using terms from application "ModuleFinder"
             return my _additional_paths & (module paths)
         --end using terms from
     end tell
end module_paths

(*!@abstruct set additional locations to search for libraries.
@param locations (list) : a list of folder paths
@result script : me
@example
tell script "ModuleLoader"
	set_additional_paths({"/yourhome/Library/Scripts", "/Library/Scripts"})
	module_paths()
	-- {"/yourhome/Library/Scripts", "/Library/Scripts", "/Users/yourhome/Library/Scripts/Modules", "/Users/yourhome/Library/Script Libraries", "/Library/Scripts/Modules", "/Library/Script Libraries", "/Network/Library/Scripts/Modules", "/Network/Library/Script Libraries"}
end tell
*)
on set_additional_paths(locations)
	set my _additional_paths to (locations as list)
	return me
end set_additional_paths

(* keep private
@abstruct
Prepend a location into the additional locations added by set_additional_paths.
@param a_path (text) : a path
@result script : me
@example
tell script "ModuleLoader"
    set_additional_paths({"/yourhome/Library/Scripts", "/Library/Scripts"})
    prepend_path("/newpath")
    module_paths()
    -- {"/newpath", "/Users/yourhome/Library/Scripts/Modules", "/Users/yourhome/Library/Script Libraries", "/Library/Scripts/Modules", "/Library/Script Libraries", "/Network/Library/Scripts/Modules", "/Network/Library/Script Libraries"}
end tell
*)
on prepend_path(a_path)
	if my _additional_paths is missing value then
		set my _additional_paths to {a_path}
	else
		set my _additional_paths to (a_path as list) & my _additional_paths
	end if
	return me
end prepend_path

(*!@group Others *)
(*!@abstruct
Obtain version number of a loaded library.
@param a_script (script) : a loaded library.
@result text : version
@example
use SimpleTextLib : script "SampleLibs/SimpleTextLib"
tell script "ModuleLoader"
    setup(me)
    module_version_of(SimpleTextLib)
    -- "1.5"
end tell
*)
on module_version_of(a_script)
    set a_moduleinfo to my _module_cache's module_for_script(a_script)
    if a_moduleinfo is missing value then
        return missing value
    end if
    a_moduleinfo's module_version()
end module_version_of

(*!@abstruct
Export a specified script object to other libraries before setup().

Use to provide a library without loading a file.

Add a script into the library cache for testing.
@param a_script (script) : a script to be a library
@result script : me
@example
property ExtendedTextLib : "@module"

script SimpleTextLib
    on hello()
        return "hello"
    end hello
end script
 
tell script "ModuleLoader"
    export(SimpleTextLib)
    setup(me)
end tell
ExtendedTextLib's hello() -- "hello"
*)
on export(a_script) -- save myself to cache when load a module which load myself.
    set end of my _exported to a_script
    return me
end export

(* @group Local Loader *)

(*!@abstruct Generate a local loader script
@description
Local loader is an applet of which script's parent is a result of this handler.
Save the following example an applet with stay open option.
Libraries can be located in the folder the applet is in.

@result script : local loader
@example
(* An example of a local loader.
   Save as SampleLocalLoader.app with "Stay Open" option.
*)
property parent : script "ModuleLoader"'s local_loader()

@example
(* An example of a script which obtains a library thru a local loader.*)
property LibForLocalLoader : "@module"
-- Customize behaivior of the local loader with defining special properties.
property _only_local_ : true  -- if true, location to search for libraries is limited under the location the local loader is in
 -- if true, the local loader searches for libraries at only the folder the local loader is in.
property _collecting_modules_ : true -- if true, alias files for libraries which is not under the local loader are created at the folder the local loader is in.

application (get "SampleLocalLoader")'s loader()'s setup(me)
*)
on local_loader()
	return load script (path to resource "LocalLoader.scpt")
end local_loader

-- use property _only_local_
on set_localonly(a_flag)
	set my _only_local to a_flag
	return me
end set_localonly

-- use property _collecting_modules_
on collecting_modules(a_flag)
	set my _collecting to a_flag
	return me
end collecting_modules

on set_local(a_flag)
	set my _is_local to true
	return me
end set_local

on try_collect(mspec, adpaths)
	--log "start try_collect"
	tell application (my _module_finder)
		--using terms from application "ModuleFinder"
			set a_record to load module mspec additional paths adpaths
		--end using terms from
	end tell
	set {file:a_source, script:a_script} to a_record
	set a_source to a_source as alias
	set a_location to item 1 of adpaths
	tell application id "com.apple.finder"
		set src_name to name of a_source
		try
			set new_alias to make alias file at a_location to a_source with properties {name:src_name}
		on error msg number errno
			error msg & return & "Failed to make an alias file of " & (quoted form of name of mspec) number errno
		end try
	end tell
	return a_record
end try_collect

on set_loadonly(a_flat)
	set my _loadonly to a_flag
	return me
end set_loadonly

on set_logging(a_flag, loader_name)
	if a_flag then
		set my _logger to ConsoleLog's make_with(loader_name)
	else
		set my _logger to missing value
	end if
	
	return a reference to me
end set_logging

on clear_cache()
	set my _module_cache to make ModuleCache
	return me
end clear_cache
