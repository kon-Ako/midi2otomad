local M = {}

debug_print("Initiating MIDI2Otomad...")

M.PI = M.PI or math.pi
M.sqrt = M.sqrt or math.sqrt
M.atan = M.atan or math.atan2
M.cos = M.cos or math.cos
M.sin = M.sin or math.sin
M.floor = M.floor or math.floor
M.ppq = 960

M.BPM = 160
M.mesPlus = 0
M.framePlus = 0
M.metre = 4


---@param time timeSecond
---@return timeBeat
function M.toBeat(time)
    return time*M.BPM/60
end

-- inverse
---@param time timeBeat
---@return timeSecond
function M.unBeat(time)
    return time*60/M.BPM
end

return M