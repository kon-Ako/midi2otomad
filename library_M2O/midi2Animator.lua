debug_print("Loading midi2Animator.lua")

local M = {}

debug_print("Initiating MIDI2Otomad...")

M.CacheMidi         = {}
M.CacheNotePress    = {}
M.CacheLayer        = {path = {}}
M.CacheMisc         = {zoom = {}}

--Default values

M.scriptPath = "C:\\ProgramData\\aviutl2\\Script\\midi2otomad"
M.ppq = 960
M.bpm = 160
M.mesPlus = 0
M.framePlus = 0
M.metre = 4

M.curFrame  = 0
M.totFrame  = 60
M.curBeat   = 0
M.curMes    = 0
M.furBeat   = 0
M.furMes    = 0

---@param x number      [0,1] of animation, starting at 0 and ending at 1
---@param amp number    Amplitude used in some of easing
---@return number       [0,1] eased to appropraiate function. If index%3 is 2, it is a bounce: achieves 1 at middle and 0 at either end.
M.ease = {
    --linear
    [1] = function(x, amp) return x end,
    --triangle
    [2] = function(x, amp) return 1-math.abs(2*x-1) end,
    --quadratic in
    [3] = function(x, amp) return x^2 end,
    --quadratic out
    [4] = function(x, amp) return 1-(1-x)^2 end,
    --quadratic bounce
    [5] = function(x, amp) return 1-(1-2*x)^2 end,
    --cubic in
    [6] = function(x, amp) return x^3 end,
    --cubic out
    [7] = function(x, amp) return 1-(1-x)^3 end,
    --cubic bounce
    [8] = function(x, amp) return 1-math.abs((1-2*x)^3) end,
    --polynomial in
    [9] = function(x, amp) return x^amp end,
    --polynomial out
    [10] = function(x, amp) return 1-(1-x)^amp end,
    --polynomial bounce
    [11] = function(x, amp) return 1-math.abs((1-2*x))^amp end,
    --exponential in
    [12] = function(x, amp) return (2^(amp*(x-1))-2^-amp)/(1-2^-amp) end,
    --exponential out
    [13] = function(x, amp) return 1-((2^(-amp*x)-2^-amp)/(1-2^-amp)) end,
    --exponential bounce
    [14] = function(x, amp) return (1+2^(-amp)-2^(-amp*x)-2^(amp*(x-1)))/(1+2^(-amp)-2^(1-amp/2)) end,
    --sine in
    [15] = function(x, amp) return math.sin(x*math.pi/2) end,
    --sine out
    [16] = function(x, amp) return 1-math.cos(x*math.pi/2) end,
    --sine bounce
    [17] = function(x, amp) return math.sin(x*math.pi) end
}

---@param time timeSecond
---@return timeBeat
function M.toBeat(time)
    return time*M.bpm/60
end

-- inverse
---@param time timeBeat
---@return timeSecond
function M.unBeat(time)
    return time*60/M.bpm
end

---@param num number    number
---@return number       sign of the number
function M.sign(num)
    return (num>0) and 1 or ((num<0) and -1 or 0)
end

function M.findLatestNote(currentTime, noteEvents, lastIndexRead)
    lastIndexRead = lastIndexRead or 1

    local val, nextVal, nextnextVal= noteEvents.time[lastIndexRead], (noteEvents.time[lastIndexRead+1] or noteEvents.time[lastIndexRead]*2), (noteEvents.time[lastIndexRead+2] or noteEvents.time[lastIndexRead]*2)
    --Immediately check if the current index & the next index is a candidate; set lastIndexRead to 1 if time is reveresed back.
    if((val <= currentTime) and (currentTime < nextVal)) then
        return lastIndexRead
    elseif((nextVal <= currentTime) and (currentTime < nextnextVal)) then
        return lastIndexRead+1
    elseif(val > currentTime) then
        lastIndexRead = 1
    end

    local iMin, iSup, pos= lastIndexRead, #noteEvents.time, 0
    while (iMin <= iSup) do
        pos = math.floor((iMin + iSup)/2)
        val, nextVal = noteEvents.time[pos], (noteEvents.time[pos+1] or noteEvents.time[pos]*2)
        if((val <= currentTime) and (currentTime < nextVal)) then
            return pos
        elseif (val < currentTime) then
            iMin = pos + 1
        else
            iSup = pos - 1
        end
    end

    return pos
end

function M.playNote(currentTime, noteEvents, index)
    local sustain = currentTime - noteEvents.time[index]
    local sustNorm = sustain/noteEvents.length[index]
    local isPressed = sustNorm <= 1
    return sustain, sustNorm, isPressed
end

function M.playLatestNote(currentTime, noteEvents, lastIndexRead)
    local index = M.findLatestNote(currentTime, noteEvents, lastIndexRead)
    local sustain, sustNorm, isPressed = M.playNote(currentTime, noteEvents, index)
    return index, sustain, sustNorm, isPressed
end

return M