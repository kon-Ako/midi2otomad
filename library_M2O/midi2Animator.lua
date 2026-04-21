debug_print("Loading midi2Animator.lua")

local M = {}

---@alias timeBeat number   time in unit of beats
---@alias timeSecond number time in unit of seconds. For exmle, obj.time

---@class PlayData              table of the values of note currenlty played.
---@field index integer         index of the note the data was taken from.
---@field sustain timeBeat      the time since the note started was pressed. negative if it is upcoming note.
---@field sustNorm number       the sustain, divided by the length of the note
---@field wasPressed boolean    whether the note was ever active
---@field wasReleased boolean   whether the note has ended being pressed
---@field isPressed boolean     whether the note is currently active or not
---@field anim number           sustain divided by latest length track
---@field animIndex integer     index accounted by latest delayIndex
---@field animSign integer      sign used to multiply animEased
---@field animEased number      anim processed through latest easing function
M.PlayData = {
    currentFrame = 0,
    index = 1,
    sustain = 0,
    sustNorm = 0,
    wasPressed = false,
    wasReleased = false,
    isPressed = false,
    anim = 0,
    animIndex = 1,
    animSign = 1,
    animEased = 0
}
M.PlayData.__index = M.PlayData

---Create new PlayData
---@param instance? table       If given, turns that table into MidiNotes instead of making new object
---@return PlayData instance    PlayData with default value
function M.PlayData:new(instance)
    instance = instance or {}
    setmetatable(instance, self)
    instance.currentFrame = 0
    instance.index = 1
    instance.sustain = 0
    instance.sustNorm = 0
    instance.wasPressed = false
    instance.wasReleased = false
    instance.isPressed = false
    return instance
end

---Returns the inside of PlayData
---@return string s     All value with explanation
function M.PlayData:tostring()
    return "At frame: "..self.currentFrame.." / "..M.totFrame..
    "\nPlaying note #: "..self.index..
    "\nSustain: "..(math.floor(self.sustain*100)/100)..
    "\nNormalized: "..(math.floor(self.sustNorm*100)/100)..
    "\nNote is currently pressed: "..tostring(self.isPressed)..
    "\nNote was ever pressed: "..tostring(self.wasPressed)..
    "\nNote was ever released:"..tostring(self.wasReleased)
end
M.PlayData.__tostring = M.PlayData.tostring

---@class SequencedImage        Used to store some properties of filepath
---@field pathGeneral string    File path without the numbers and type
---@field extensionIndx integer The index where fiele extension begins
---@field fileExtension string  File extension including period
---@field is0Filled boolean     Whether the sequenced image index fill higher unused digit with 0 or not
---@field totalDigits integer   Used when is0Filled is true. Total digits used to fill.
---@field startFrame integer    The first frame of the sequence found
---@field finalFrame integer    Final frame of the sequence found
M.SequencedImage = {
    pathGeneral = "",
    extensionIndx = 1,
    fileExtension = ".png",
    is0Filled = false,
    totalDigits = 0,
    startFrame = 1,
    finalFrame = 2
}
M.SequencedImage.__index = M.SequencedImage

---Create new SequencedImage
---@param pathObj string            Path of the Sequenced Image
---@param instance? table           If given, turns that table into ParsedNoteEvents instead of making new object
---@return SequencedImage instance  Used to store some properties of filepath
function M.SequencedImage:new(pathObj, instance)
    instance = instance or {}
    setmetatable(instance, self)
    local extensionIndx, strStartFrame = nil, ""
    extensionIndx, _, strStartFrame, instance.fileExtension = pathObj:find("(%d+)(%.[^%.]+)$")
    if(not extensionIndx) then
        obj.load("text", "Invalid Sequenced Image!\n読み込んだファイルは連番画像ではありません！")
        obj.draw()
        return instance
    end
    instance.extensionIndx = extensionIndx
    instance.pathGeneral = pathObj:sub(1,extensionIndx-1)
    instance.startFrame = tonumber(strStartFrame)

    instance.is0Filled = (strStartFrame == tostring(instance.startFrame))

    if(instance.is0Filled) then
        instance.totalDigits = strStartFrame:len()
    end

    instance.finalFrame = instance:findFinalFrame()

    debug_print(instance.pathGeneral)
    debug_print(instance.finalFrame)

    return instance
end

---Starting with start frame, opens image one by one. Records the final frame where load wasa successful.
---@return integer totalDigits
function M.SequencedImage:findFinalFrame()
    local flag = true
    local frame= self.startFrame
    while(flag) do
        flag = obj.load("image", self:getCompletePath(frame))
        frame = frame + 1
    end
    self.finalFrame = frame - 2
    debug_print("final frame found was "..tostring(self.finalFrame))
    return self.finalFrame
end

---Depending on how the Sequenced Image is numbered, returns appropriate file path to load the given frame.
---@param frame integer         The number of the frame to load.
---@return string completePath  The complete filepath to load.
function M.SequencedImage:getCompletePath(frame)
    local string = self.pathGeneral
    if(self.is0Filled) then
        string = string..string.rep("0", self.totalDigits - 1 - math.floor(math.log(frame, 10) or 0))
    end
    return string..frame..self.fileExtension
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
M.ease = {
    --linear
    ---@param x number      progress of animation. Assumes it starts at 0 and ends at 1.
    ---@param m number      Magnitude used in some of easing.
    ---@return number anim  progress eased by appropraiate function. If index%3 is 2, it is a bounce: achieves 1 at middle and 0 at either end.
    [1] = function(x, m) return x end,
    --triangle
    [2] = function(x, m) return 1-math.abs(2*x-1) end,
    --quadratic in
    [3] = function(x, m) return x^2 end,
    --quadratic out
    [4] = function(x, m) return 1-(1-x)^2 end,
    --quadratic bounce
    [5] = function(x, m) return 1-(1-2*x)^2 end,
    --cubic in
    [6] = function(x, m) return x^3 end,
    --cubic out
    [7] = function(x, m) return 1-(1-x)^3 end,
    --cubic bounce
    [8] = function(x, m) return 1-math.abs((1-2*x)^3) end,
    --polynomial in
    [9] = function(x, m) return x^m end,
    --polynomial out
    [10] = function(x, m) return 1-(1-x)^m end,
    --polynomial bounce
    [11] = function(x, m) return 1-math.abs((1-2*x))^m end,
    --exponential in
    [12] = function(x, m) return (2^(m*(x-1))-2^-m)/(1-2^-m) end,
    --exponential out
    [13] = function(x, m) return 1-((2^(-m*x)-2^-m)/(1-2^-m)) end,
    --exponential bounce
    [14] = function(x, m) return (1+2^(-m)-2^(-m*x)-2^(m*(x-1)))/(1+2^(-m)-2^(1-m/2)) end,
    --sine in
    [15] = function(x, m) return math.sin(x*math.pi/2) end,
    --sine out
    [16] = function(x, m) return 1-math.cos(x*math.pi/2) end,
    --sine bounce
    [17] = function(x, m) return math.sin(x*math.pi) end
}
---Calls the above functions, and forces x to be [0,1]
---@param x number      progress of animation. Assumes it starts at 0 and ends at 1.
---@param m number    Magnitude used in some of easing.
---@param index integer The index of easing function.
---@return number anim  progress eased by appropraiate function. If index%3 is 2, it is a bounce: achieves 1 at middle and 0 at either end.
function M.ease.force(x, m, index)
    return M.ease[index](math.max(0, math.min(1, x)),m)
end

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

---Find the last note pressed
---@param currentTime timeBeat      time in beats
---@param ListNotes MidiNotes       table of note events, decoded
---@param lastIndexRead? integer    index to start calculation from
---@return integer pos              the latest note
function M.findLatestNote(currentTime, ListNotes, lastIndexRead)
    lastIndexRead = lastIndexRead or 1

    local val1 = ListNotes.time[lastIndexRead] or 0
    local val2 = ListNotes.time[lastIndexRead+1] or ListNotes.time[lastIndexRead]*2
    local val3 = ListNotes.time[lastIndexRead+2] or ListNotes.time[lastIndexRead]*2
    --Immediately check the likeliest index
    if((val1 <= currentTime) and (currentTime < val2)) then
        --Immediately check if the current index is a candidate
        return lastIndexRead
    elseif((val2 <= currentTime) and (currentTime < val3)) then
        --Then check if the next index is candidate
        return lastIndexRead+1
    elseif(currentTime < ListNotes.time[1]) then
        --return 0 if even 1st note isn't played.
        return 0
    elseif(val1 > currentTime) then
        --set lastIndexRead to 1 if time is reveresed back.
        lastIndexRead = 1
    end

    local iMin, iSup, pos= lastIndexRead, #ListNotes.time, 0
    while (iMin <= iSup) do
        pos = math.floor((iMin + iSup)/2)
        val1, val2 = ListNotes.time[pos], (ListNotes.time[pos+1] or ListNotes.time[pos]*2)
        if((val1 <= currentTime) and (currentTime < val2)) then
            return pos
        elseif (val1 < currentTime) then
            iMin = pos + 1
        else
            iSup = pos - 1
        end
    end

    return pos
end

M.bufferNote = M.PlayData:new()
---Updates the PlayData's value to that of given index. Returns the play data of the given note.
---@param currentTime timeBeat  time in beats
---@param listNotes MidiNotes   list of notes, decoded
---@param index integer         index to play
---@param instance? PlayData    the buffer table to store value; default to the M.bufferNote
---@return PlayData instance    The updated PlayData table
function M.playNote(currentTime, listNotes, index, instance)
    instance = instance or M.bufferNote
    instance.currentFrame = M.curFrame
    instance.sustain = currentTime - (listNotes.time[index] or currentTime-1) --If note doesn't exist, defaults to 1
    instance.sustNorm = instance.sustain/(listNotes.length[index] or 1)
    instance.wasPressed = (instance.sustNorm >= 0)
    instance.wasReleased = (instance.sustNorm >= 1)
    instance.isPressed = (not instance.wasReleased) and instance.wasPressed
    return instance
end

---Updates the PlayData's value to that of latest index. Returns the play data of the given note.
---@param currentTime timeBeat      time in beats
---@param ListNotes MidiNotes       list of notes, decoded
---@param lastIndexRead? integer    index to start calculation from
---@param instance? PlayData        the buffer table to store value; default to the M.bufferNote
---@return PlayData instance        The updated PlayData table
function M.playLatestNote(currentTime, ListNotes, lastIndexRead, instance)
    instance = instance or M.bufferNote
    if(instance.currentFrame ~= M.curFrame or instance == M.bufferNote) then
        instance.index = M.findLatestNote(currentTime, ListNotes, lastIndexRead)
        M.playNote(currentTime, ListNotes, instance.index, instance)
    end
    return instance
end

return M