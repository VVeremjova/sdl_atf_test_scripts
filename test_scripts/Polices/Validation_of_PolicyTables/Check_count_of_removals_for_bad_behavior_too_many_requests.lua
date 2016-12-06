---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies] "usage_and_error_counts" and "count_of_rpcs_sent_in_hmi_none" update.
--
-- Description:
-- In case an application has been unregistered with any of:
-- -> TOO_MANY_PENDING_REQUESTS,
-- -> TOO_MANY_REQUESTS,
-- -> REQUEST_WHILE_IN_NONE_HMI_LEVEL resultCodes,
-- Policy Manager must increment "count_of_removals_for_bad_behavior" section value
-- of Local Policy Table for the corresponding application.

-- Pre-conditions:
-- a. SDL and HMI are started
-- b. app successfully registers and running in NONE

-- Steps:
-- 1. Application is sending more requests than AppHMILevelNoneTimeScaleMaxRequests in
-- AppHMILevelNoneRequestsTimeScale milliseconds:
-- appID->AnyRPC()
-- 2. Application is unregistered:
-- SDL->appID: OnAppUnregistered(REQUEST_WHILE_IN_NONE_HMI_LEVEL)

-- Expected:
-- 3. PoliciesManager increments value of <count_of_removals_for_bad_behavior>

-- Thic

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local mobile_session = require('mobile_session')

-- local variables
local count_of_requests = 1000
-- AppHMILevelNoneTimeScaleMaxRequests

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

-- Precondition: application is activate
--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test.Precondition_StopSDL()
  StopSDL()
end
function Test.Precondition_StartSDL()
  StartSDL(config.pathToSDL, config.ExitOnCrash)
end

function Test:Precondition_initHMI()
  self:initHMI()
end

function Test:Precondition_initHMI_onReady()
  self:initHMI_onReady()
end

function Test:Precondition_ConnectMobile()
  self:connectMobile()
end

function Test:Precondition_StartSession()
  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
end

function Test:RegisterApp()
  self.mobileSession:StartService(7)
  :Do(function (_,_)
      local correlationId = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)

      EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered")
      :Do(function(_,data)
          HMIAppID = data.params.application.appID
        end)
      EXPECT_RESPONSE(correlationId, { success = true })
      EXPECT_NOTIFICATION("OnPermissionsChange")
    end)
end

function Test:ActivateAppInFull()
  commonSteps:ActivateAppInSpecificLevel(self,HMIAppID,"FULL")
end

--[[ end of Preconditions ]]
function Test:Send_TOO_MANY_REQUESTS()

  for i=1, count_of_requests do
    local cid = self.mobileSession:SendRPC("AddCommand",
      {
        cmdID = i,
        menuParams =
        {
          position = 0,
          menuName ="Command"..tostring(i)
        }
      })
    -- EXPECT_HMICALL("UI.AddCommand")
    -- :Do(function(_,data)
    -- self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
    -- end)
  end
  -- EXPECT_RESPONSE("AddCommand", { success = false, resultCode = "GENERIC_ERROR" }):Times(count_of_requests):Timeout(150000)
  EXPECT_RESPONSE("AddCommand")
  :ValidIf(function(exp,data)
      if
      data.payload.resultCode == "TOO_MANY_PENDING_REQUESTS" then
        TooManyPenReqCount = TooManyPenReqCount+1
        print(" \27[32m AddCommand response came with resultCode TOO_MANY_PENDING_REQUESTS \27[0m")
        return true
      elseif
        data.payload.resultCode == "GENERIC_ERROR" then
          print(" \27[32m AddCommand response came with resultCode GENERIC_ERROR \27[0m")
          return true
        else
          print(" \27[36m AddCommand response came with resultCode "..tostring(data.payload.resultCode .. "\27[0m" ))
          return false
        end
      end)
    :Times(count_of_requests)
    :Timeout(150000)

    EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered") --,
    -- --mobile side: expect notification
    EXPECT_NOTIFICATION("OnAppInterfaceUnregistered", {{reason = "TOO_MANY_REQUESTS"}})
  end
  function Test:Check_TOO_MANY_REQUESTS_in_DB()

  end

  -- Precondition: application is activated
  -- function Test:Check_TOO_MANY_REQUESTS()
  -- end

  -- function Test:Check_TOO_MANY_PENDING_REQUESTS()

  -- end

  return Test
