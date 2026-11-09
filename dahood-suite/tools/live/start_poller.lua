-- starts the workspace file poller (_poller.lua: runs _cmd_<name>.lua, writes _res_<name>.txt) on this client
local ok, err = pcall(function() loadstring(readfile("_poller.lua"))() end)
return ok, tostring(err), typeof(getgenv().POLLER_STOP), game:GetService("Players").LocalPlayer.Name
