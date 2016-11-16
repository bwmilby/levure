# levure 

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The actual framework code is not complicated. Common functionality is added via Helpers.
2. Designed for use with version management. Wherever possible configuration and scripts are text based files. While developers can take advantage of the efficiency of binary stack files for the UI, all scripts should be handled via behaviors. Behaviors are stored as script only stacks in a `behaviors` folder alongside the binary stack. Each behavior stack is assigned to the `stackfiles` property of the binary stack so that the engine automatically finds them when the stack is opened.

## Try Out Sample Application

1. Open the `sample_app/standalone.livecode` stack in LiveCode 8+. The `framework/levureFramework.livecodescript` stack is a behavior of this stack.
2. Switch to the browser tool and click on the `Run Application` button.
3. The `MyApp` stack should open up and display some information in a field.

The `MyApp` stack shows how to use behaviors for the stack scripts. The app also loads a library that the stack uses.

## Organizing a Levure Framework Application

The framework is distributed in a `framework` folder that can be stored anywhere on your computer. The `levure.livecodescript` stack file is assigned as a behavior to the mainstack in the `standalone.livecode` stack file.

Your app is configured using the `app.yml` YAML file. This file can be alongside the `standalone.livecode` stack file or directly within a folder that resides alongside the `standalone.livecode` stack file.

Alongside the `app.yml` file is the `app.livecodescript` stack file.

Alongside the `app.yml` file you may have a `components`, `libraries`, `frontscripts`, `backscripts`, or `helpers` folder. 

The `components` folder is where you will store the stacks used for your user interface. Each UI stack has a folder for the binary stack and a subfolder named behaviors for any behaviors assigned to the stack. The behavior stacks should be assigned to the `stackfiles` property of the UI stack so that they are loaded into memory as needed.

The `helpers` folder is for files that work together to add a specific piece of functionality to an application. The folder can contain stack files meant to be used for UI, libraries, frontscripts, or backscripts. It can also contain externals.

In the `app.yml` file you can load components, libraries, backscripts, frontscripts, and helpers from any location on your computer, even the LiveCode User Extensions folder. When your application is packaged up all of the necessary resources will be brought together to build the final application.

### An example

- app.yml
- app.livecodescript
- standalone.livecode
- framework/levure.livecodescript
- framework/helpers/app_files_and_urls/frontscript.livecodescript
- framework/helpers/app_files_and_urls/helper.yml
- components/
  - preferences/
    - preferences.livecode
    - behaviors/
      - card.livecodescript
      - stack.livecodescript
  - document window/
    - document.livecode
    - behaviors/
      - card.livecodescript
      - stack.livecodescript
      - tools.livecodescript
- libraries/
  - libcontrols.livecodescript
  - libdatahelpers.livecodescript
- backscripts/
  - mybackscript.livecodescript
- frontscripts/
  - myfrontscripts.livecodescript
- helpers/
  - miscellaneous/
    - helper.yml
    - ui.livecode
    - frontscript.livecodescript
    - backscript.livecodescript
    - library.livecodescript
  - logging/
    - helper.yml
    - library.livecodescript
  - preferences/
    - helper.yml
    - library.livecodescript
    - preference.bundle
  - my external
    - helper.yml
    - macos.bundle
    - windows.dll
    - linux.so
  
## app.yml

An application is configured using the `app.yml` file. This file can be located alongside the `standalone.livecode` stack file or directly within any folder located alongside the `standalone.livecode` stack file.

```
password: ?????
multiple instances: true|false
relaunch in background: true|false
components:
  1:
    name: [stack name in memory]
    filename: [relative path to stack file within components folder]
  2:
    folder: [path to folder containing components]
libraries:
  1: 
    filename: [relative path to stack file within libraries folder]
  2: 
    folder: [relative path a folder with library stacks]
  ...
frontscripts:
  1: 
    filename: [relative path to stack file within frontscripts folder]
  2: 
    folder: [relative path a folder with frontscript stacks]
  ...
backscripts:
  1: 
    filename: [relative path to stack file within backscript folder]
  2: 
    folder: [relative path a folder with backscript stacks]
  ...
helpers:
  1: 
    filename: [relative path to folder containing helper]
  2: 
    folder: [relative path a folder with helper folders]
  ...
file extensions:
  JPEG File: jpg,jpeg
file extension groups:
  Media Files:
    1:
      name: All Supported Files
      extensions: png,gif,bmp,txt
    2:
      name: Text Files
      extensions: txt
    3:
      name: Image Files
      extensions: png,gif,bmp
copy files:
  all:
    ...
  macos:
    ...
  win:
    ...
  linux:
    ...
```

## standalone.livecode

This stack is used to build the standalone application. The `levureFramework.livecodescript` stack file should be assigned to the stackFiles of this stack. The `levureFramework` stack should be assigned as the behavior of this stack. This stack can be named whatever you would like in memory.

## app.livecodescript

This stack file must be located directly alongside the `app.yml` file. The stack must be named `app` in memory. It has the following handlers for handling framework messages:

- `InitializeApplication`: Initialize your application. Framework has loaded at this point.
- `OpenApplication`: Open your application window.
- `ProcessURL`: First parameter is line delimited list of urls that your app has been requested to process.
- `ProcessFiles`: First parameter is line delimited list of files that your application supports and that you should process.
  
## levureFramework.livecodescript

The framework logic is located in the `levure.livecodescript` file. The stack must be assigned as the behavior of another stack which is assumed to be the `standalone.livecode` stack. The `levureInitializeAndRunApplication` will initialize and load the framework. Here is what happens during loading:

1. if an sAppA script local exists and the stack is running in the development environment  then use values from that. It means the app has been packaged. Otherwise load the `app.yml` file, searching first alongside the `standalone.livecode` stack file and then directly within any folders that are alongside the `standalone.livecode` stack. If `app.yml` is not found then app cannot be loaded.
2. Process any command line arguments using the `app_files_and_urls` helper.
3. Load `app.livecodescript` from folder containing the `app.yml` file.
4. Load helpers. By default any helpers in a folder named `helpers` that sits alongside the `levure.livecodescript` file or the `app.yml` file will be loaded. You can configure additional folders where helpers are located using the `helper source folders` config property. ` All externals, libraries, backscripts, and frontscripts will be loaded into memory. The ui stacks will be added to the list of stackFiles to be assigned to `app` stack. `PreloadExternals` message is sent to `app` stack so that developer can add or remove from list of externals prior to loading.*
8. Add list of stacks defined in `components` key in config file to stackFiles list.
5. Load app libraries and start using.
6. Load app backscripts and insert.
7. Load app frontscripts and insert.
9. Assign stackFiles list to stackFiles property of `app` stack.
10. Dispatch `InitializeApplication` to `app` stack.
11. Dispatch `OpenApplication` to `app` stack.

[*] As an alternative the developer could add or remove helpers as needed during packaging. We move the entire folder over to tmp folder, developer can prune it, and that gets packaged up. No need to dispatch message. Currently this message is not being sent.
  
## Relaunching Application

In the `app.yml` file you can configure a `multiple instances` property. Set to true if you want your application to support multiple instances. If `multiple instances` is `false` and you don't want the defaultStack to come forward when the user relaunches the application then set `relaunch in background` to true. 

When the `relaunch` message is processed by the levure standalone a `RelaunchApplication` message will be dispatched to the `app` stack. If your application requires any special logic for bringing windows forward then it should be handled here. If any command line parameters are passed in to `relaunch` then the `ProcessCommandLineParameters` message will be dispatched to the `app` stack as well.

## Packaging an Application

- Create a stack for behaviors
  - Make all behavior stacks substacks of that stack.

## Helpers (plugins)

Helpers provide additional common functionality to an application. A helper consists of a folder, a config.yml file, and any supporting files. A helper can be made up of the following;

- library stacks
- backscripts
- frontscripts
- ui stacks
- externals

### Specifying locations of Helpers

The framework will always look for a Helpers folder alongside the framework stack file as well as the `app.yml` file. YOu can specify additional folders that contain Helpers using the `helper source folders` configuration property. You can use the `{{USER_EXTENSIONS}}` variable in a Helper path to specify the path returned by `revEnvironmentCustomizationPath()` in the IDE. This allows you to store commonly used helpers in your LiveCode User Extension folder.

#### Example:

```
helper source folders:
  1: ../../../Common Helpers"
  2: {{USER_EXTENSIONS}}/Helpers"
```

## Helpers Included with Framework

### app_files_and_urls

Helps with files associated with your application as well as when the OS asks your application to process a url. Also includes functions for generating file dialog type filter strings.

`ProcessFiles` message sent to `app` stack. Check `appGetFilesToProcessOnOpen` when app opens for files passed on command line.

`ProcessURL` message sent to `app` stack. Check `appGetURLsToProcessOnOpen()` when app opens for urls passed on the command line.

## Helpers to build:

- preference
- window manager
- logging
- MAS (security-scoped filenames and licensing)
- auto update
- error dialog