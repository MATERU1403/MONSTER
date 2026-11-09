-- read the done-flags the watch / scenario scripts leave in getgenv
local g = getgenv()
return tostring(g.WATCH_DONE), tostring(g.SCENARIO_DONE), tostring(g.CAP_DONE)
