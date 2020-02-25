#include <Carbon/Carbon.r>

#define Reserved8   reserved, reserved, reserved, reserved, reserved, reserved, reserved, reserved
#define Reserved12  Reserved8, reserved, reserved, reserved, reserved
#define Reserved13  Reserved12, reserved
#define dp_none__   noParams, "", directParamOptional, singleItem, notEnumerated, Reserved13
#define reply_none__   noReply, "", replyOptional, singleItem, notEnumerated, Reserved13
#define synonym_verb__ reply_none__, dp_none__, { }
#define plural__    "", {"", kAESpecialClassProperties, cType, "", reserved, singleItem, notEnumerated, readOnly, Reserved8, noApostrophe, notFeminine, notMasculine, plural}, {}

resource 'aete' (0, "ModuleFinder Terminology") {
	0x1,  // major version
	0x0,  // minor version
	english,
	roman,
	{
		"Type Names Suite",
		"Hidden terms",
		kASTypeNamesSuite,
		1,
		1,
		{
			/* Events */

		},
		{
			/* Classes */

			"script", 'scpt',
			"",
			{
			},
			{
			}
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
		},

		"ModuleLoader Suite",
		"treat script modules",
		'Molo',
		1,
		1,
		{
			/* Events */

			"find module",
			"Find module from module paths. If specified module can not be forund, the error number 1800 will raise.",
			'Molo', 'fdMo',
			'file',
			"A reference to a module.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'TEXT',
			"A module name",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"additional paths", 'inDr', 'file',
				"Additional locations to search modules.",
				optional,
				listOfItems, notEnumerated, Reserved13,
				"version", 'vers', 'TEXT',
				"Required version.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"other paths", 'ohPh', 'bool',
				"If tue is passed,  module search paths are restricted to paths given in 'additional paths'.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"load module",
			"Load a module from module paths. If specified module can not be forund, the error number 1800 will raise. ",
			'Molo', 'loMo',
			'****',
			"A recod of a loaded module.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'****',
			"A module name or a module specifier",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"additional paths", 'inDr', 'file',
				"Additional locations to search modules.",
				optional,
				listOfItems, notEnumerated, Reserved13,
				"version", 'vers', 'TEXT',
				"Required version.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"other paths", 'ohPh', 'bool',
				"If tue is passed,  module search paths are restricted to  paths given in 'additional paths'.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"module paths",
			"List module paths. The default paths are ~/Library/Scritps/Modules and /Library/Scripts/Modules. Only existing folders are listed. Additional paths given by \"set additional paths to\" will be included in the result.",
			'Molo', 'gtPH',
			'TEXT',
			"List of POSIX paths of folders.",
			replyRequired, listOfItems, notEnumerated, Reserved13,
			dp_none__,
			{

			},

			"set additional module paths to",
			"Prepend module search paths.",
			'Molo', 'adMp',
			'bool',
			"If success return true",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'****',
			"Folders including script modules or missing value to remove additional module paths",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{

			},

			"module",
			"Make a module specifier record. Must be placed in a user defined propery statement or in an argument of load handler of a loader object. If a module name is ommited, property name is used as a module name.",
			'Molo', 'MkMs',
			'****',
			"A module specifer record",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'TEXT',
			"A module name.",
			directParamOptional,
			singleItem, notEnumerated, Reserved13,
			{
				"version", 'vers', 'TEXT',
				"Required version.",
				optional,
				singleItem, notEnumerated, Reserved13,
				"reloading", 'pRLo', 'bool',
				"Whether or not to load a module ignoring module chache.",
				optional,
				singleItem, notEnumerated, Reserved13
			},

			"extract dependencies",
			"Extarct module specifier records from a module script.",
			'Molo', 'ExDP',
			'****',
			"list of dependency info",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'****',
			"",
			directParamOptional,
			singleItem, notEnumerated, Reserved13,
			{
				"for", 'frso', '****',
				"script object",
				required,
				singleItem, notEnumerated, Reserved13
			},

			"meet the version",
			"check wheter the version numver meet the condition.",
			'Molo', 'MeVe',
			'bool',
			"True if the version meet the condition.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'TEXT',
			"A version number.",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"condition", 'ConD', 'TEXT',
				"A required version condition.",
				required,
				singleItem, notEnumerated, Reserved13
			},

			"check module loaded",
			"check wheter module_loaded_by handler exists or not",
			'Molo', 'ckML',
			'bool',
			"",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'****',
			"",
			directParamOptional,
			singleItem, notEnumerated, Reserved13,
			{
				"for", 'frso', '****',
				"script object",
				required,
				singleItem, notEnumerated, Reserved13
			},

			"module loaded",
			"Called when a module is loaded by a loader object. It's a place to customize modules.",
			'Molo', 'wlLd',
			reply_none__,
			'scpt',
			"",
			directParamRequired,
			singleItem, notEnumerated, Reserved13,
			{
				"by", 'whLD', 'scpt',
				"A loader object",
				optional,
				singleItem, notEnumerated, Reserved13
			}
		},
		{
			/* Classes */

			"module specifier", 'MoSp',
			"A specifier of a module will be loaded.",
			{
				"name", 'pnam', 'TEXT',
				"Module name",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"reloading", 'pRLo', 'bool',
				"Whether or not to load a module ignoring module chache.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"version", 'vers', 'TEXT',
				"Required version.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"from use", 'fmUs', 'bool',
				"Obtained from use statement.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			},

			"dependency info", 'DpIf',
			"Module dependency information",
			{
				"name", 'pnam', 'TEXT',
				"A property name which a module is loaded.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"module specifier", 'MoSp', 'MoSp',
				"A module specifier",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			},

			"local loader options", 'OPll',
			"",
			{
				"collecting modules", 'cLMd', 'bool',
				"",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"only local", 'oNLo', 'bool',
				"",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			},

			"has module loaded", 'hsML',
			"Module dependency information",
			{
				"name", 'pnam', 'TEXT',
				"A property name which a module is loaded.",
				reserved, singleItem, notEnumerated, readWrite, Reserved12,

				"module specifier", 'MoSp', 'MoSp',
				"A module specifier",
				reserved, singleItem, notEnumerated, readWrite, Reserved12
			},
			{
			}
		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
		},

		"HelpBook Suite",
		"Treat Help Books in bundles",
		'HBsu',
		1,
		1,
		{
			/* Events */

			"show helpbook",
			"Show a help book in specfied bundle with Help Viewer.",
			'HBsu', 'shHB',
			'TEXT',
			"The name of the registered help book.",
			replyRequired, singleItem, notEnumerated, Reserved13,
			'file',
			"A reference to a bundle which contains a help book.",
			directParamOptional,
			singleItem, notEnumerated, Reserved13,
			{

			}
		},
		{
			/* Classes */

		},
		{
			/* Comparisons */
		},
		{
			/* Enumerations */
		}
	}
};
