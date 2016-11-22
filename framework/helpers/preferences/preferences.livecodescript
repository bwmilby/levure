﻿script "Application Preferences Library"
constant kUserPrefStackname = "pref stack - user"
constant kSharedPrefStackname = "pref stack - shared"

local sUseExternal
local sDefaultPrefsA, sDefaultSharedPrefsA
local sPrefsA


on libraryStack
  if the target is not me then pass libraryStack
  
  put null into sPrefsA
  
  _loadDefaultPreferences
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


private function useExternal pUserOrShared
  if sUseExternal is empty then    
    set the wholematches to true
    put the platform is "macos" and "Preferences" is among the lines of levureExternalsLoadedInMemory() into sUseExternal
  end if
  
  return sUseExternal and (pUserOrShared is "user")
end useExternal


private function prefFilenameForPlatform pPlatform
  local tA
  
  if pPlatform is empty then put the platform into pPlatform
  if pPlatform is "win32" then put "win" into pPlatform
  put "preferences" into tA[1]
  put pPlatform into tA[2]
  put "filename" into tA[3]
  return levureAppGet(tA)
end prefFilenameForPlatform


private command _loadDefaultPreferences
  local tYamlFile
  
  put levureAppFolder() & "/prefs.yml" into tYamlFile
  if there is a file tYamlFile then
    put yamlFileToArray(tYamlFile) into sDefaultPrefsA
    put the result into tError
  end if
  
  if tError is empty then
    put levureAppFolder() & "/prefs_shared.yml" into tYamlFile
    if there is a file tYamlFile then
      put yamlFileToArray(tYamlFile) into sDefaultSharedPrefsA
      put the result into tError
    end if
  end if
  
  return tError
end _loadDefaultPreferences


function appGetDefaultPrefs pUserOrShared
  if pUserOrShared is "shared" then
    return sDefaultSharedPrefsA
  else
    return sDefaultPrefsA
  end if
end appGetDefaultPrefs


command appResetPrefs pUserOrShared
  if pUserOrShared is not "shared" then put "user" into pUserOrShared
  
  ## OS X external behavior
  if useExternal(pUserOrShared) then
    /* 
    Implement once we switch to a module
    http://stackoverflow.com/questions/8259786/cocoa-resetting-nsuserdefaults
    */
  else
    put empty into sPrefsA
    appSavePrefs
    
    put 1 into sPrefsA["init"]
    delete local sPrefsA["init"]
  end if
end appResetPrefs


/**
* \brief Sets an application preference.
* \param pKey Name of preference to set.
* \param pValue Value to set preference to. This can be a string or an array.
* \param pUserOrShared Pass in "shared" to set a pref in shared preferences. Leave empty for default behavior.
* \param pType Pass in "binary" to force pref to be stored as binary (OS X). By default if value contains NULL then it will be stored as binary.
*
* \package Preferences
*
* \return error message
*/
command appSetPref pKey, pValue, pUserOrShared, pType
  local tStack, tError
  
  if pUserOrShared is not "shared" then put "user" into pUserOrShared
  
  ## OS X external behavior
  if useExternal(pUserOrShared) then
    if the keys of pValue is empty then
      if pValue contains NULL OR pType is "binary" then
        osxHLPrefSetBinary pKey, "pValue", prefFilenameForPlatform()
      else
        # encode strings as UTF8 or this will fail in LC 8. Convert to module at some point.
        osxHLPrefSetString pKey, textEncode(pValue, "utf8"), prefFilenameForPlatform()
      end if
    else
      put "_LCA" & arrayEncode(pValue) into pValue
      osxHLPrefSetBinary pKey, "pValue", prefFilenameForPlatform()
    end if
    put the result into tError
    
  else
    _ensurePrefsAreLoaded pUserOrShared
    put pValue into sPrefsA[pUserOrShared][pKey]
  end if
  
  # Broadcasting is one of framework helpers
  appBroadcast "prefs", pKey, empty
  
  return tError
end appSetPref


/**
* \brief Gets an application preference.
* \param pKey Name of preference to get.
*
* \package Preferences
*
* \return value
*/
function appGetPref pKey, pUserOrShared
  local tStack, tValue
  
  if pUserOrShared is not "shared" then put "user" into pUserOrShared
  
  if not appPrefIsSet(pKey, pUserOrShared) then    
    if pUserOrShared is "shared" then
      put sDefaultSharedPrefsA[pKey] into tValue
    else
      put sDefaultPrefsA[pKey] into tValue
    end if  
  else
    if useExternal(pUserOrShared) then
      local tValueA
      
      osxHLPrefGet pKey, "tValueA", prefFilenameForPlatform()
      if the result is empty then
        switch tValueA["type"]
          case "binary"
            if tValueA["value"] begins with "_LCA" then
              try ## Assume everything is an array. If it fails then tValue stays the same
                put arrayDecode(char 5 to -1 of tValueA["value"]) into tValue
              end try
            else
              put tValueA["value"] into tValue
            end if
            break
          case "string"
          default
            put textDecode(tValueA["value"], "utf8") into tValue
            break
        end switch
      end if
      
    else
      _ensurePrefsAreLoaded pUserOrShared
      put sPrefsA[pUserOrShared][pKey] into tValue
    end if
    
  end if
  
  return tValue
end appGetPref


/**
* \brief Checks if a preference has been set on the computer the application is running on.
* \param pKey Name of preference to check.
*
* \return true/false
*/
function appPrefIsSet pKey, pUserOrShared
  local tStack
  
  if pUserOrShared is not "shared" then put "user" into pUserOrShared
  
  ## OS X external behavior
  if useExternal(pUserOrShared) then
    
    return osxHLPrefExists(pKey, prefFilenameForPlatform())
    
  else
    _ensurePrefsAreLoaded pUserOrShared
    if not the result then
      answer param(0) && "tried to check preference but preferences could not be loaded:" && pKey & "."
      return false
    end if
    
    return pKey is among the keys of sPrefsA
  end if
end appPrefIsSet


/**
* \brief Saves preferences to disk.
* \param pKey Name of preference to check.
*
* When setting preferences the preference is updated in memory. To permanently
* store changes on disk use this command.
*
* \return Error message
*/
command appSavePrefs pUserOrShared
  local tError, tFile
  
  if pUserOrShared is not "shared" then put "user" into pUserOrShared
  
  put appGetPreferenceFile(pUserOrShared) into tFile
  
  ## OS X external behavior
  if useExternal(pUserOrShared) then
    
    osxHLPrefSavePrefs prefFilenameForPlatform()
    put the result into tError
    
  else
    
    saveContentsToFile tFile, arrayEncode(sPrefsA)
    put the result into tError
    
  end if
  
  return theError
end appSavePrefs


function appGetPreferenceFile pType  
  local tFile
  
  put prefFilenameForPlatform() into tFile
  
  if tFile is not empty then
    if pType is "user" then
      return _systemPreferencesFolder() & slash & tFile
    else
      return _systemApplicationDataFolder("shared") & slash & tFile
    end if
  else
    return empty
  end if
end appGetPreferenceFile


private function _systemPreferencesFolder
  if the platform is "macos" then
    return specialFolderPath("preferences")
  else if the platform is "win32" then
    return _systemApplicationDataFolder("user")
  else if the platform is "linux" then
    return specialFolderPath("home")
  else
    return empty
  end if
end _systemPreferencesFolder


private function _systemApplicationDataFolder pUserOrShared
  local tDefaultFolder
  local tPath
  
  if pUserOrShared is not "shared" then
    put "user" into pUserOrShared
  end if
  
  if pUserOrShared is "user" then
    if the platform is "macos" then
      put specialFolderPath("support") into tPath
    else if the platform is "linux" then
      put specialFolderPath("home") into tPath
    else if the platform is "win32" then
      ## VERSIONS PRIOR TO WIN2000 USE REGISTRY SINCE SPECIALFOLDERPATH DOESN'T RETURN PROPER VALUE
      if word 2 of the systemVersion >= 5 then
        put specialFolderPath(26) into tPath ## USER APPLICATION DATA FOLDER
      end if
      
      if tPath is empty or tPath is "\\" then # Seen "\\" returned for redirected folder in a domain
        put queryRegistry("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\" & \
              "CurrentVersion\Explorer\Shell Folders\AppData") into tPath
        replace "\" with "/" in tPath ## Convert to LiveCode slashes
      end if
    end if
    
  else
    ## SHARED
    if the platform is "macos" then
      put specialFolderPath("asup") into tPath
    else if the platform is "linux" then
      put "/opt" into tPath
    else                    
      ## VERSIONS PRIOR TO WIN2000 USE REGISTRY SINCE SPECIALFOLDERPATH DOESN'T RETURN PROPER VALUE
      if word 2 of the systemVersion >= 5 then
        put specialFolderPath(35) into tPath
      end if
      
      if tPath is empty or tPath is "\\" then
        put queryRegistry("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\" & \
              "CurrentVersion\Explorer\Shell Folders\Common AppData") into tPath
        replace "\" with "/" in tPath
      end if
    end if
  end if
  
  return tPath
end _systemApplicationDataFolder


private command _ensurePrefsAreLoaded pUserOrShared
  if sPrefsA is null then
    if pUserOrShared is "shared" then
      put appGetPreferenceFile("shared") into tFile
    else
      put appGetPreferenceFile("user") into tFile
    end if
    
    if there is a file tFile then
      put readFileContents(tFile) into tData
      put the result into tError
      
      if tError is empty then
        if tData is not empty then
          put arrayDecode(tData) into sPrefsA
        else
          put empty into sPrefsA
        end if
        return true
      else
        return false
      end if
    else
      put 1 into sPrefsA["init"]
      delete local sPrefsA["init"]
      return true
    end if
  else
    return true
  end if
end _ensurePrefsAreLoaded


private function _errorMsg pMsg, pError
  if pError is not empty then
    return pMsg && "[" & pError & "]"
  else
    return empty
  end if
end _errorMsg


private function readFileContents pFilename
  local tError
  
  open file pFilename for read
  put the result into tError
  
  if tError is empty then
    read from file pFilename until eof
    if the result is not "eof" then
      put the result into tError
    end if
    
    close file pFilename
  end if
  
  if tError is empty then
    return it for value
  else
    return tError && "(" & pFilename & ")" for error
  end if
end readFileContents


private command saveContentsToFile pFilename, pData
  local tError
  
  put pFilename & ".tmp" into tTempFilename
  
  open file tTempFilename for binary write
  put the result into tError
  
  if tError is empty then
    write pData to file tTempFilename
    put the result into tError
    
    close file tTempFilename
  end if
  
  if tError is not empty then
    put "(" & pFilename & ")" after tError
  end if
  
  if tError is empty then
    rename file tTempFilename to pFilename
    put _errorMsg("renaming temp file" && tTempFilename, the result) into tError
  end if
  
  if tError is empty then
    return empty for value
  else
    return tError && "(" & pFilename & ")" for error
  end if
end saveContentsToFile