ModuleLoader
===============

ModuleLoader is a system for managing and loading libraries(modules) of AppleScript.

In OS X 10.9, built-in support of libraries was introduced to AppleScript, which called as "AppleScript Libraries". 
ModuleLoader is a yet another library system, which has been developed from 2006 before release of OS X 10.9, and has been maintained without interruption until now.

ModuleLoader have a similar function to "AppleScript Libraries" as follows.
* Find a library from predefined locations and load the library as a script object.
* Libraries are searched from following sub-folders under user's home directory and the root directory.
  - Library/Scripts/Modules
  - Library/Script Libraries
* Sub-libraries required by the loaded library are automatically loaded.
* The version of a library to be loaded can be specified.

## Usage
English :
* https://www.script-factory.net/XModules/ModuleLoader/en/index.html

Japanese :
* http://www.script-factory.net/XModules/OSAX/ModuleLoader/index.html

## Reqirements
* OS X 10.9 or later.

## Licence

Copyright &copy; 2006-2020 Kurita Tetsuro
Licensed under the [GPL license][GPL].
 
[GPL]: http://www.gnu.org/licenses/gpl.html

