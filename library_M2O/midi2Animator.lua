debug_print("Loading midi2Animator.lua")

local M = {}

---@alias timeBeat number   time in unit of beats
---@alias timeSecond number time in unit of seconds. For example, obj.time

---@class PlayData              table of the values of note currenlty played.
---@field index integer         index of the note the data was taken from.
---@field sustain timeBeat      the time since the note started was pressed. negative if it is upcoming note.
---@field sustNorm number       the sustain, divided by the length of the note
---@field wasPressed boolean    whether the note was ever active
---@field wasReleased boolean   whether the note has ended being pressed
---@field isPressed boolean     whether the note is currently active or not
M.PlayData = {
    index = 1,
    sustain = 0,
    sustNorm = 0,
    wasPressed = false,
    wasReleased = false,
    isPressed = false
}
M.PlayData.__index = M.PlayData

---Create new PlayData
---@param instance? table       If given, turns that table into MidiNotes instead of making new object
---@return PlayData instance    PlayData with default value
function M.PlayData:new(instance)
    instance = instance or {}
    setmetatable(instance, self)
    instance.index = 1
    instance.sustain = 0
    instance.sustNorm = 0
    instance.wasPressed = false
    instance.wasReleased = false
    instance.isPressed = false
    return instance
end

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

--List of easing functions
---@param x number      [0,1] of animation, starting at 0 and ending at 1
---@param amp number    Amplitude used in some of easing
---@return number anim  [0,1] eased to appropraiate function. If index%3 is 2, it is a bounce: achieves 1 at middle and 0 at either end.
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

---@param time timeSecond   time in seconds
---@return timeBeat time    time in beats
function M.toBeat(time)
    return time*M.bpm/60
end

--- inverse
---@param time timeBeat     time in beats
---@return timeSecond time  time in seconds
function M.unBeat(time)
    return time*60/M.bpm
end

---Extract sign
---@param num number    number
---@return number sign  sign of the number
function M.sign(num)
    return (num>0) and 1 or ((num<0) and -1 or 0)
end

---@param currentTime timeBeat      time in beats
---@param ListNotes MidiNotes       table of note events, decoded
---@param lastIndexRead? integer    index to start calculation from
---@return integer pos              the latest note
function M.findLatestNote(currentTime, ListNotes, lastIndexRead)
    lastIndexRead = lastIndexRead or 1

    local val, nextVal, nextnextVal= ListNotes.time[lastIndexRead], (ListNotes.time[lastIndexRead+1] or ListNotes.time[lastIndexRead]*2), (ListNotes.time[lastIndexRead+2] or ListNotes.time[lastIndexRead]*2)
    --Immediately check if the current index & the next index is a candidate; set lastIndexRead to 1 if time is reveresed back.
    if((val <= currentTime) and (currentTime < nextVal)) then
        return lastIndexRead
    elseif((nextVal <= currentTime) and (currentTime < nextnextVal)) then
        return lastIndexRead+1
    elseif(val > currentTime) then
        lastIndexRead = 1
    end

    local iMin, iSup, pos= lastIndexRead, #ListNotes.time, 0
    while (iMin <= iSup) do
        pos = math.floor((iMin + iSup)/2)
        val, nextVal = ListNotes.time[pos], (ListNotes.time[pos+1] or ListNotes.time[pos]*2)
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

M.bufferNote = M.PlayData:new()

---Returns the play data of the given note.
---@param currentTime timeBeat  time in beats
---@param listNotes MidiNotes   list of notes, decoded
---@param index integer         index to play
---@param instance? PlayData    the buffer table to store value; default to the M.bufferNote
---@return timeBeat sustain     the time since the note started was pressed. negative if it is upcoming note.
---@return number sustainNorm   the sustain, divided by the length of the note
---@return boolean isPressed    whether the note is currently active or not
---@return boolean wasPressed   whether the note was ever active
---@return boolean wasReleased  whether the note has ended being pressed
function M.playNote(currentTime, listNotes, index, instance)
    instance = instance or M.bufferNote
    instance.sustain = currentTime - listNotes.time[index]
    instance.sustNorm = instance.sustain/listNotes.length[index]
    instance.wasPressed = (instance.sustNorm >= 0)
    instance.wasReleased = (instance.sustNorm >= 1)
    instance.isPressed = (not instance.wasReleased) and instance.wasPressed
    return instance.sustain, instance.sustNorm, instance.isPressed, instance.wasPressed, instance.wasReleased
end

---Returns the play data of the latest note.
---@param currentTime timeBeat      time in beats
---@param ListNotes MidiNotes       list of notes, decoded
---@param lastIndexRead? integer    index to start calculation from
---@param instance? PlayData        the buffer table to store value; default to the class
---@return integer index            index to play
---@return number sustain           the time since the note started was pressed. negative if it is upcoming note.
---@return number sustNorm          the sustain, divided by the length of the note
---@return boolean isPressed        whether the note is currently active or not
---@return boolean wasPressed       whether the note was ever active
---@return boolean wasReleased      whether the note has ended being pressed
function M.playLatestNote(currentTime, ListNotes, lastIndexRead, instance)
    instance = instance or M.bufferNote
    instance.index = M.findLatestNote(currentTime, ListNotes, lastIndexRead)
    M.playNote(currentTime, ListNotes, instance.index, instance)
    return instance.index, instance.sustain, instance.sustNorm, instance.isPressed, instance.wasPressed, instance.wasReleased
end

return M