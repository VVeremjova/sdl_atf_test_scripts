---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [GetStatusUpdate] Request from HMI
--
-- Description:
-- SDL must respond with the current update status code to HMI
-- In case HMI needs to find out current status of PTU and sends GetStatusRequest to SDL
--
-- Preconditions:
-- 1. App 123_xyz is not registered
--
-- Steps:
-- 1. Register new app 123_xyz
-- 2. HMI -> SDL: Send GetStatusUpdate() and verify status of response
-- 3. Verify that PTU sequence is started
-- 4. HMI -> SDL: Send GetStatusUpdate() and verify status of response
-- 5. Verify that PTU sequence is finished
-- 6. HMI -> SDL: Send GetStatusUpdate() and verify status of response
--
-- Expected result:
-- 2. Status: UPDATE_NEEDED
-- 4. Status: UPDATING
-- 6. Status: UP_TO_DATE
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local mobileSession = require("mobile_session")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local testCasesForBuildingSDLPolicyFlag = require('user_modules/shared_testcases/testCasesForBuildingSDLPolicyFlag')
local testCasesForPolicyAppIdManagament = require("user_modules/shared_testcases/testCasesForPolicyAppIdManagament")

--[[ Local Functions ]]

--[[ General Precondition before ATF start ]]
testCasesForBuildingSDLPolicyFlag:CheckPolicyFlagAfterBuild("EXTERNAL_PROPRIETARY")
commonFunctions:SDLForceStop()
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require("connecttest")
require("user_modules/AppTypes")

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:UpdatePolicy()
  testCasesForPolicyAppIdManagament:updatePolicyTable(self, "files/jsons/Policies/Related_HMI_API/ptu_24047_1.json")
end

function Test:Test_0_UP_TO_DATE()
  local reqId = self.hmiConnection:SendRequest("SDL.GetStatusUpdate")
  EXPECT_HMIRESPONSE(reqId, {status = "UP_TO_DATE"})
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:StartNewSession()
  self.mobileSession2 = mobileSession.MobileSession(self, self.mobileConnection)
  self.mobileSession2:StartService(7)
end

function Test:RegisterNewApp()
  config.application2.registerAppInterfaceParams.appName = "New Application"
  config.application2.registerAppInterfaceParams.appID = "123_xyz"
  local corId = self.mobileSession2:SendRPC("RegisterAppInterface", config.application2.registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered",
    { application = { appName = config.application2.registerAppInterfaceParams.appName }})
  :Do(function(_, data)
      self.applications[config.application2.registerAppInterfaceParams.appName] = data.params.application.appID
    end)
  self.mobileSession2:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
end

function Test:Test_1_UPDATE_NEEDED()
  local reqId = self.hmiConnection:SendRequest("SDL.GetStatusUpdate")
  EXPECT_HMIRESPONSE(reqId, {status = "UPDATE_NEEDED"})
end

function Test:Test_2_UPDATING()
  local policy_file_path = "/tmp/fs/mp/images/ivsu_cache/"
  local policy_file_name = "PolicyTableUpdate"
  local file = "files/jsons/Policies/Related_HMI_API/ptu_24047_2.json"

  EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
  :Times(1)
  :Do(function(_, _)
      local reqId = self.hmiConnection:SendRequest("SDL.GetStatusUpdate")
      EXPECT_HMIRESPONSE(reqId, {status = "UPDATING"})
      local requestId = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
      EXPECT_HMIRESPONSE(requestId, {result = {code = 0, method = "SDL.GetURLS", urls = {{url = "http://policies.telematics.ford.com/api/policies"}}}})
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest", {requestType = "PROPRIETARY", fileName = policy_file_name})
      EXPECT_NOTIFICATION("OnSystemRequest", { requestType = "PROPRIETARY" })
      :Do(function(_, _)
          local corIdSystemRequest = self.mobileSession:SendRPC("SystemRequest", {requestType = "PROPRIETARY", fileName = policy_file_name}, file)
          EXPECT_HMICALL("BasicCommunication.SystemRequest")
          :Do(function(_, data)
              self.hmiConnection:SendResponse(data.id, "BasicCommunication.SystemRequest", "SUCCESS", {})
              self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate", {policyfile = policy_file_path .. policy_file_name})
            end)
          EXPECT_RESPONSE(corIdSystemRequest, { success = true, resultCode = "SUCCESS"})
          :Do(function(_, _)
              requestId = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"StatusUpToDate"}})
              EXPECT_HMIRESPONSE(requestId)
            end)
        end)
    end)
end

function Test:Test_3_UP_TO_DATE()
  local reqId = self.hmiConnection:SendRequest("SDL.GetStatusUpdate")
  EXPECT_HMIRESPONSE(reqId, {status = "UP_TO_DATE"})
end

return Test
