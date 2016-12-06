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

-- local variables
local count_of_requests = 500
-- AppHMILevelNoneTimeScaleMaxRequests

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
require('user_modules/AppTypes')

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

-- Precondition: application is NONE

function Test:Check_REQUEST_WHILE_IN_NONE_HMI_LEVEL()

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
    EXPECT_RESPONSE(cid, { success = false, resultCode = "DISALLOWED" }):Timeout(20000)
  end

  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered") --,
  -- {appID = self.applications[config.application1.registerAppInterfaceParams.appName], unexpectedDisconnect = true})

  -- --mobile side: expect notification
  EXPECT_NOTIFICATION("OnAppInterfaceUnregistered", {{reason = "REQUEST_WHILE_IN_NONE_HMI_LEVEL"}})
end
function Test:Check_REQUEST_WHILE_IN_NONE_HMI_LEVEL()

  -- -- local cid = self.mobileSession:SendRPC("ListFiles",{})
  -- -- EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
  -- local cid = self.mobileSession:SendRPC("PutFile",
  -- {
  -- syncFileName = "action",
  -- fileType = "GRAPHIC_PNG",
  -- persistentFile = false,
  -- systemFile = false
  -- },
  -- "files/action.png")

  -- --mobile side: expect Futfile response
  -- EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })

  -- for i=1, count_of_requests-1 do
  -- local cid = self.mobileSession:SendRPC("ListFiles",{})
  -- -- EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
  -- --mobile side: expect Futfile response
  -- EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
  -- -- EXPECT_RESPONSE(cid, { success = false, resultCode = "INVALID_DATA" })
  -- end

  -- local cid = self.mobileSession:SendRPC("PutFile",
  -- {
  -- syncFileName = "action",
  -- fileType = "GRAPHIC_PNG",
  -- persistentFile = false,
  -- systemFile = false
  -- },
  -- "files/action.png")

  -- --mobile side: expect Futfile response
  -- EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })

  -- for i=1, 5 do
  -- local cid = self.mobileSession:SendRPC("SetAppIcon",{syncFileName = "action"})
  -- -- EXPECT_HMICALL("UI.SetAppIcon", { })
  -- -- :Do(function(_,data)
  -- -- self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
  -- -- end)
  -- -- EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
  -- end

  -- for i=1, 5 do
  -- -- local cid = self.mobileSession:SendRPC("SetAppIcon",{syncFileName = "action"})
  -- EXPECT_HMICALL("UI.SetAppIcon", { })
  -- :Do(function(_,data)
  -- self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
  -- end)
  -- EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
  -- end

  -- EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered",
  -- {appID = self.applications[config.application1.registerAppInterfaceParams.appName], unexpectedDisconnect = false})

  -- --mobile side: expect notification
  -- EXPECT_NOTIFICATION("OnAppInterfaceUnregistered", {{reason = "REQUEST_WHILE_IN_NONE_HMI_LEVEL"}})
end

-- Precondition: application is activated
-- function Test:Check_TOO_MANY_REQUESTS()
-- end

-- function Test:Check_TOO_MANY_PENDING_REQUESTS()

-- end

return Test
