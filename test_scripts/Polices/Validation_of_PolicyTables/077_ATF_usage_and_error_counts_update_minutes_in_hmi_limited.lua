---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies] "usage_and_error_counts" and "minutes_in_hmi_limited" update
--
-- Check update value of "minutes_in_hmi_limited" in Local Policy Table.
-- 1. Used preconditions:
-- Start default SDL
-- Add MobileApp to PreloadedPT
-- InitHMI register MobileApp in NONE
--
-- 2. Performed steps:
-- Wait <M> minutes
-- Activate MobileApp NONE -> LIMITED
-- Wait <N> minutes
-- Stop SDL
-- Check LocalPT changes
-- Start SDL
-- InitHMI register MobileApp in NONE
-- Wait <Y> minutes
-- Activate MobileApp NONE -> LIMITED
-- Wait <X> minutes
-- Stop SDL
-- Check LocalPT changes
--
-- Expected result:
-- SDL must: increment value of "minutes_in_hmi_limited" for this <X+N> minutes in Local Policy Table.
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
Test = require('connecttest')
local config = require('config')
config.defaultProtocolVersion = 2
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local json = require("modules/json")
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
local mobile_session = require('mobile_session')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Local Variables ]]
local PRELOADED_PT_FILE_NAME = "sdl_preloaded_pt.json"
local HMIAppId
local N_MINUTES = 2
local M_MINUTES = 1
local X_MINUTES = 1
local Y_MINUTES = 3
local APP_ID = "0000001"

local TESTED_DATA = {
  preloaded = {
    policy_table = {
      app_policies = {
        [APP_ID] = {
          keep_context = false,
          steal_focus = false,
          priority = "NONE",
          default_hmi = "NONE",
          groups = {"Base-4"},
          RequestType = {
            "TRAFFIC_MESSAGE_CHANNEL",
            "PROPRIETARY",
            "HTTP",
            "QUERY_APPS"
          }
        }
      }
    }
  },
  expected = {
    policy_table = {
      usage_and_error_counts = {
        app_level = {
          [APP_ID] = {
            minutes_in_hmi_full = 0,
            minutes_in_hmi_limited = 4,
            minutes_in_hmi_background = 0,
            minutes_in_hmi_none = 0
          }
        }
      }
    }
  },
  application = {
    registerAppInterfaceParams = {
      syncMsgVersion = {
        majorVersion = 3,
        minorVersion = 0
      },
      appName = "Test Application",
      isMediaApplication = true,
      languageDesired = 'EN-US',
      hmiDisplayLanguageDesired = 'EN-US',
      appHMIType = { "MEDIA" },
      appID = APP_ID,
      deviceInfo = {
        os = "Android",
        carrier = "Megafon",
        firmwareRev = "Name: Linux, Version: 3.4.0-perf",
        osVersion = "4.4.2",
        maxNumberRFCOMMPorts = 1
      }
    }
  }
}

local TestData = {
  path = config.pathToSDL .. "TestData",
  isExist = false,
  init = function(self)
    if not self.isExist then
      os.execute("mkdir ".. self.path)
      os.execute("echo 'List test data files files:' > " .. self.path .. "/index.txt")
      self.isExist = true
    end
  end,
  store = function(self, message, pathToFile, fileName)
    if self.isExist then
      local dataToWrite = message

      if pathToFile and fileName then
        os.execute(table.concat({"cp ", pathToFile, " ", self.path, "/", fileName}))
        dataToWrite = table.concat({dataToWrite, " File: ", fileName})
      end

      dataToWrite = dataToWrite .. "\n"
      local file = io.open(self.path .. "/index.txt", "a+")
      file:write(dataToWrite)
      file:close()
    end
  end,
  delete = function(self)
    if self.isExist then
      os.execute("rm -r -f " .. self.path)
      self.isExist = false
    end
  end,
  info = function(self)
    if self.isExist then
      commonFunctions:userPrint(35, "All test data generated by this test were stored to folder: " .. self.path)
    else
      commonFunctions:userPrint(35, "No test data were stored" )
    end
  end
}

local function constructPathToDatabase()
  if commonSteps:file_exists(config.pathToSDL .. "storage/policy.sqlite") then
    return config.pathToSDL .. "storage/policy.sqlite"
  elseif commonSteps:file_exists(config.pathToSDL .. "policy.sqlite") then
    return config.pathToSDL .. "policy.sqlite"
  else
    commonFunctions:userPrint(31, "policy.sqlite is not found" )
    return nil
  end
end

local function executeSqliteQuery(rawQueryString, dbFilePath)
  if not dbFilePath then
    return nil
  end
  local queryExecutionResult = {}
  local queryString = table.concat({"sqlite3 ", dbFilePath, " '", rawQueryString, "'"})
  local file = io.popen(queryString, 'r')
  if file then
    local index = 1
    for line in file:lines() do
      queryExecutionResult[index] = line
      index = index + 1
    end
    file:close()
    return queryExecutionResult
  else
    return nil
  end
end

local function isValuesCorrect(actualValues, expectedValues)
  if #actualValues ~= #expectedValues then
    return false
  end

  local tmpExpectedValues = {}
  for i = 1, #expectedValues do
    tmpExpectedValues[i] = expectedValues[i]
  end

  local isFound
  for j = 1, #actualValues do
    isFound = false
    for key, value in pairs(tmpExpectedValues) do
      if value == actualValues[j] then
        isFound = true
        tmpExpectedValues[key] = nil
        break
      end
    end
    if not isFound then
      return false
    end
  end
  if next(tmpExpectedValues) then
    return false
  end
  return true
end

function Test.checkLocalPT(checkTable)
  local expectedLocalPtValues
  local queryString
  local actualLocalPtValues
  local comparationResult
  local isTestPass = true
  for _, check in pairs(checkTable) do
    expectedLocalPtValues = check.expectedValues
    queryString = check.query
    actualLocalPtValues = executeSqliteQuery(queryString, constructPathToDatabase())
    if actualLocalPtValues then
      comparationResult = isValuesCorrect(actualLocalPtValues, expectedLocalPtValues)
      if not comparationResult then
        TestData:store(table.concat({"Test ", queryString, " failed: SDL has wrong values in LocalPT"}))
        TestData:store("ExpectedLocalPtValues")
        commonFunctions:userPrint(31, table.concat({"Test ", queryString, " failed: SDL has wrong values in LocalPT"}))
        commonFunctions:userPrint(35, "ExpectedLocalPtValues")
        for _, values in pairs(expectedLocalPtValues) do
          TestData:store(values)
          print(values)
        end
        TestData:store("ActualLocalPtValues")
        commonFunctions:userPrint(35, "ActualLocalPtValues")
        for _, values in pairs(actualLocalPtValues) do
          TestData:store(values)
          print(values)
        end
        isTestPass = false
      end
    else
      TestData:store("Test failed: Can't get data from LocalPT")
      commonFunctions:userPrint(31, "Test failed: Can't get data from LocalPT")
      isTestPass = false
    end
  end
  return isTestPass
end

function Test.backupPreloadedPT(backupPrefix)
  os.execute(table.concat({"cp ", config.pathToSDL, PRELOADED_PT_FILE_NAME, " ", config.pathToSDL, backupPrefix, PRELOADED_PT_FILE_NAME}))
end

function Test.restorePreloadedPT(backupPrefix)
  os.execute(table.concat({"mv ", config.pathToSDL, backupPrefix, PRELOADED_PT_FILE_NAME, " ", config.pathToSDL, PRELOADED_PT_FILE_NAME}))
end

local function updateJSON(pathToFile, updaters)
  local file = io.open(pathToFile, "r")
  local json_data = file:read("*a")
  file:close()

  local data = json.decode(json_data)
  if data then
    for _, updateFunc in pairs(updaters) do
      updateFunc(data)
    end
    -- Workaround. null value in lua table == not existing value. But in json file it has to be
    data.policy_table.functional_groupings["DataConsent-2"].rpcs = "tobedeletedinjsonfile"
    local dataToWrite = json.encode(data)
    dataToWrite = string.gsub(dataToWrite, "\"tobedeletedinjsonfile\"", "null")
    file = io.open(pathToFile, "w")
    file:write(dataToWrite)
    file:close()
  end

end

function Test.preparePreloadedPT()
  local preloadedUpdaters = {
    function(data)
      data.policy_table.app_policies[APP_ID] = TESTED_DATA.preloaded.policy_table.app_policies[APP_ID]
    end
  }
  updateJSON(config.pathToSDL .. PRELOADED_PT_FILE_NAME, preloadedUpdaters)
end

local function activateAppInSpecificLevel(self, HMIAppID, hmi_level)
  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = HMIAppID, level = hmi_level})

  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = hmi_level, systemContext = "MAIN" })
  --hmi side: expect SDL.ActivateApp response
  EXPECT_HMIRESPONSE(RequestId)
  :Do(function(_,data)
      --In case when app is not allowed, it is needed to allow app
      if data.result.isSDLAllowed ~= true then
        --hmi side: sending SDL.GetUserFriendlyMessage request
        RequestId = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage",
          {language = "EN-US", messageCodes = {"DataConsent"}})

        EXPECT_HMIRESPONSE(RequestId)
        :Do(function(_,_)

            --hmi side: send request SDL.OnAllowSDLFunctionality
            self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
              {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = "127.0.0.1"}})

            --hmi side: expect BasicCommunication.ActivateApp request
            EXPECT_HMICALL("BasicCommunication.ActivateApp")
            :Do(function(_,data2)

                --hmi side: sending BasicCommunication.ActivateApp response
                self.hmiConnection:SendResponse(data2.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
              end)
            -- :Times()
          end)
      end
    end)
end

local function deactivateApp(self, HMIAppID)
  self.hmiConnection:SendNotification("BasicCommunication.OnAppDeactivated", {appID = HMIAppID})
end

local function wait(delaySeconds)
  local sleepCommand = table.concat({"sleep ", delaySeconds / 4})
  commonFunctions:userPrint(35, table.concat({"Start waiting ", delaySeconds, " seconds"}))
  for i = 1, 4 do
    os.execute(sleepCommand)
    commonFunctions:userPrint(35, table.concat({25 * i, "%"}))
  end
end

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:Precondition_StopSDL()
  TestData:init(self)
  StopSDL()
end

function Test:Precondition_PreparePreloadedPT()
  commonSteps:DeletePolicyTable()
  TestData:store("Store initial PreloadedPT", config.pathToSDL .. PRELOADED_PT_FILE_NAME, "initial_" .. PRELOADED_PT_FILE_NAME)
  self.backupPreloadedPT("backup_")
  self:preparePreloadedPT()
  TestData:store("Store updated PreloadedPT", config.pathToSDL .. PRELOADED_PT_FILE_NAME, "updated_" .. PRELOADED_PT_FILE_NAME)
end

function Test:Precondition_StartSDL()
  StartSDL(config.pathToSDL, config.ExitOnCrash, self)
end

function Test:Precondition_InitHMI()
  self:initHMI()
end

function Test:Precondition_InitHMI_onReady()
  self:initHMI_onReady()
end

function Test:Precondition_ConnectMobile()
  self:connectMobile()
end

function Test:Precondition_StartMobileSession()
  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
  self.mobileSession:StartService(7)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:RegisterApp()
  local correlationId = self.mobileSession:SendRPC("RegisterAppInterface", TESTED_DATA.application.registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered")
  :Do(function(_,data)
      HMIAppId = data.params.application.appID
    end)
  EXPECT_RESPONSE(correlationId, { success = true })
  EXPECT_NOTIFICATION("OnPermissionsChange")
end

function Test.AppInNoneNMinutes()
  local delta = 8
  local sleepTime = N_MINUTES * 60 + delta
  wait(sleepTime)
end

function Test:ActivateApp()
  activateAppInSpecificLevel(self,HMIAppId,"FULL")
end

function Test:DeactivateApp()
  deactivateApp(self, HMIAppId)
end

function Test.AppInLimitedMMinutes()
  local delta = 4
  local sleepTime = M_MINUTES * 60 + delta
  wait(sleepTime)
end

function Test:StopSDL()
  StopSDL(self)
  TestData:store("Store first LocalPT ", constructPathToDatabase(), "first_policy.sqlite" )
  os.remove(config.pathToSDL .. "app_info.dat")
end

function Test:StartSDL()
  StartSDL(config.pathToSDL, config.ExitOnCrash, self)
end

function Test:InitHMI()
  self:initHMI()
end

function Test:InitHMI_onReady()
  self:initHMI_onReady()
end

function Test:ConnectMobile()
  self:connectMobile()
end

function Test:StartMobileSession()
  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
  self.mobileSession:StartService(7)
end

function Test:RegisterApp2()
  local correlationId = self.mobileSession:SendRPC("RegisterAppInterface", TESTED_DATA.application.registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered")
  :Do(function(_,data)
      HMIAppId = data.params.application.appID
    end)
  EXPECT_RESPONSE(correlationId, { success = true })
  EXPECT_NOTIFICATION("OnPermissionsChange")
end

function Test.AppInNoneXMinutes()
  local delta = 6
  local sleepTime = X_MINUTES * 60 + delta
  wait(sleepTime)
end

function Test:ActivateApp()
  activateAppInSpecificLevel(self,HMIAppId,"FULL")
end

function Test:DeactivateApp()
  deactivateApp(self, HMIAppId)
end

function Test.AppInLimitedYMinutes()
  local delta = 4
  local sleepTime = Y_MINUTES * 60 + delta
  wait(sleepTime)
end

function Test:StopSDL2()
  StopSDL(self)
end

function Test:CheckPTUinLocalPT()
  TestData:store("Store LocalPT after test", constructPathToDatabase(), "final_policy.sqlite" )
  local checks = {
    {
      query = table.concat(
        {
          'select minutes_in_hmi_limited from app_level where application_id = "',
          config.application1.registerAppInterfaceParams.appID,
          '"'
        }),
      expectedValues = {table.concat(
          {
            TESTED_DATA.expected.policy_table.usage_and_error_counts.app_level[config.application1.registerAppInterfaceParams.appID].minutes_in_hmi_limited, ""
          })
      }
    }
  }
  if not self.checkLocalPT(checks) then
    self:FailTestCase("SDL has wrong values in LocalPT")
  end
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition()
  --commonSteps:DeletePolicyTable()
  Test.restorePreloadedPT("backup_")
  TestData:info()
end

return Test
