debug_print("Loading midi2Animator.lua")

local M = {}

--Is this layering appropriate...?
M.MidiToAnalyzer = require("library_M2O/midi2Analyzer")
local L = M.MidiToAnalyzer

M.bufferPlayState = {} --Saves PlayState with file path as index. Is updated ev ery frame as animation changes.
M.bufferLayerPath = {} --Maps layer of object to file path of last MIDI loaded.
M.bufferSeqImage  = {} --Saves information about sequenced images.

--Default values

M.scriptPath = "C:\\ProgramData\\aviutl2\\Script\\midi2otomad"
M.ppq = 960
M.bpm = 160
M.mesPlus = 0
M.framePlus = 0
M.metre = 4

M.curFrame  = 0
M.totFrame  = 60
M.framerate = 60
M.curBeat   = 0
M.curMes    = 0
M.furBeat   = 0
M.furMes    = 0

---@alias timeBeat number   time in unit of beats
---@alias timeSecond number time in unit of seconds. For exmle, obj.time

---@class PlayState             table of the values of note currenlty played. Calculated every frame.
---@field source MidiNotes      pointer back to the original MidiNotes the PlayState will read from
---@field noteIndex integer     noteIndex of the curretnly played note.
---@field pressTime timeBeat    the time since the note was pressed. negative if it is upcoming note.
---@field pressNorm number      the pressTime, divided by the length of the note
---@field wasPressed boolean    whether the note was ever active
---@field wasReleased boolean   whether the note has ended being pressed
---@field isPressed boolean     whether the note is currently active or not
---@field progress number       pressTime divided by latest length track
---@field progressIndex integer noteIndex accounted by latest delayIndex
---@field progressSign integer  sign used to multiply progressEased
---@field progressEased number  progress processed through latest easing function
M.PlayState = {
    source = L.MidiNotes,
    currentFrame = 0,
    noteIndex = 1,
    pressTime = 0,
    pressNorm = 0,
    wasPressed = false,
    wasReleased = false,
    isPressed = false,
    progress = 0,
    progressIndex = 1,
    progressSign = 1,
    progressEased = 0
}
M.PlayState.__index = M.PlayState

---Creates new blank PlayState instance. Also stores it in M.bufferPlayState.
---@param source MidiNotes      the source MidiNotes object the PlayState will update from.
---@param instance? table       if given, turns that table into PlayState instead of making new object
---@return PlayState instance   PlayState with default value
function M.PlayState.new(source, instance)
    instance = instance or {}
    M.bufferPlayState[source.filePath] = instance
    setmetatable(instance, M.PlayState)
    instance.source = source
    instance.currentFrame = 0
    instance.noteIndex = 1
    instance.pressTime = 0
    instance.pressNorm = 0
    instance.wasPressed = false
    instance.wasReleased = false
    instance.isPressed = false
    return instance
end

---Gets an instance of PlayState at given path. Creates one if they don't exist.
---@param filePath? string                      file path used as index. If empty, uses last used filePath in that layer.
---@param doUpdate? boolean                     if true, updates the instance before returning it.
---@param forceReset? boolean                   if true, deletes the PlayState object to recreate it.
---@return PlayState|MultiPlayState playState   appropriate instance of object created
function M.PlayState.getInstance(filePath, doUpdate, forceReset)

    if(not filePath or filePath == "") then
        filePath = M.bufferLayerPath[obj.layer]
    end

    local playState = M.bufferPlayState[filePath]

    if(forceReset or not playState) then
        M.bufferPlayState[filePath] = nil
        playState = M.PlayState.new(L.MidiNotes.getInstance(filePath, forceReset))
        playState:update()
    end

    if(doUpdate) then
        playState:update()
    end

    return playState
end

---Returns the inside of PlayState
---@return string s     All value with explanation
function M.PlayState:tostring()
    return table.concat({"Reading from: ", self.source.filePath,
    "\nAt frame: ", self.currentFrame, " / ", M.totFrame,
    "\nPlaying note #: ", self.noteIndex,
    "\nSustain: ", (math.floor(self.pressTime*100)/100),
    "\nNormalized: ", (math.floor(self.pressNorm*100)/100),
    "\nNote is currently pressed: ", tostring(self.isPressed),
    "\nNote was ever pressed: ", tostring(self.wasPressed),
    "\nNote was ever released:", tostring(self.wasReleased)})
end
M.PlayState.__tostring = M.PlayState.tostring

---Update the PlayState
---@param currentBeat? timeBeat     time in beats
---@param noteIndex? integer|false  noteIndex to read; defaults to the latest note.
---@param force? boolean            if true, will always update; else, only update when frame changes.
function M.PlayState:update(currentBeat, noteIndex, force)
    currentBeat = currentBeat or M.curBeat
    noteIndex = noteIndex or self.source:getLatestNoteIndex(currentBeat, self.noteIndex)
    if(self.currentFrame ~= M.curFrame or force) then
        self.noteIndex = noteIndex
        self.currentFrame = M.curFrame
        self.pressTime = currentBeat - (self.source.time[noteIndex] or -1) --If note doesn't exist, starts at 1.
        self.pressNorm = self.pressTime / (self.source.length[noteIndex] or 1)
        self.wasPressed = (self.pressNorm >= 0)
        self.wasReleased = (self.pressNorm >= 1)
        self.isPressed = (not self.wasReleased) and self.wasPressed
    end
    M.bufferLayerPath[obj.layer] = self.source.filePath
end

---Reprocess the pressTime of note based on information from track bar.
---@param length number             length of animation, in beats
---@param isNorm boolean            if true, anim uses pressNorm instead of pressTime
---@param delayIndex integer        noteIndex is calculated with this number added instead of actual number.
---@param easing integer            specifies which easing function is used
---@param magnitude number          magnitude of easing function
---@param isDecaying integer        0 or 1. If 1, animEased transition from 1→0 instead of 0→1
---@param isSwitching integer       0 or 1. If 1, animEased swtich between decay and grow every noteIndex.
---@param isAlternating integer     0 or 1. If 1, noteIndex is multiplied by -1 every other noteIndex.
---@return number progressEased     [-1,0] XOR [0,1]. Final progress animation with easing.
function M.PlayState:getEased(length, isNorm, delayIndex, easing, magnitude, isDecaying, isSwitching, isAlternating)
    self.progressIndex = self.noteIndex + delayIndex
    isDecaying = (isDecaying + isSwitching*self.progressIndex)%2
    self.progressSign = 1-2*(isAlternating*self.progressIndex%2)
    self.progress = ((length == 0) and 1) or (isNorm and self.pressNorm or self.pressTime)/length
    self.progressEased = (isDecaying+(1-2*isDecaying)*(M.ease.force(self.progress, magnitude, easing)))*self.progressSign
    return self.progressEased
end

---@class MultiPlayState: PlayState PlayState that holds precalculated values for all notes at all frame. Planned to be used for multiobject.
---@field totalNotes integer        total amount of notes in source.
---@field totalFrame integer        total amount of frame to calculate: will extend with parent object.
---@field FIELD2DARR table          all the keys of flat 2D arrays below.
---@field latestAtFrame table       maps frame+1 (index) to the latestFrame at note
---@field multiPressTime table      flat 2D array of pressTime of each note at each frame
---@field multiPressNorm table      flat 2D array of pressNorm of each note at each frame
---@field multiWasPressed table     flat 2D array of wasPressed of each note at each frame
---@field multiWasReleased table    flat 2D array of wasReleased of each note at each frame
---@field multiIsPressed table      flat 2D array of isPressed of each note at each frame
M.MultiPlayState = {
    totalNotes = 8,
    totalFrame = M.totFrame,
    latestAtFrame = {},
    FIELD2DARR = {"multiPressTime", "multiPressNorm", "multiWasPressed", "multiWasReleased", "multiIsPressed"},
    multiPressTime = {},
    multiPressNorm = {},
    multiWasPressed = {},
    multiWasReleased = {},
    multiIsPressed = {}
}
M.MultiPlayState.__index = M.MultiPlayState
setmetatable(M.MultiPlayState, M.PlayState)

---Returns the arpproperiate value
---@param field string          the field to take from
---@param note integer          the note to take from
---@param frame integer         the frame to take from
---@return number|boolean val   the value at given field, note, and frame
function M.MultiPlayState:getNote(field, note, frame)
    return self[field][frame*self.totalNotes + note]
end

---Extends the tables of MultiPlayState up to the largest total frame.
function M.MultiPlayState:extend()
    local init = #self.multiPressTime+1
    local tN, tF = self.totalNotes, self.totalFrame
    local tbl = nil
    if(tF < M.totFrame) then
        for frame = tF+1, M.totFrame do
            self.latestAtFrame[frame] = self.source:getLatestNoteIndex(M.toBeat((frame-1)/M.framerate), self.latestAtFrame[frame-1])
        end

        --For each field of 2D array, extend each field to appropriate length.
        for _,v in ipairs(self.FIELD2DARR) do
            tbl = self[v]
            for i=init, M.totFrame*tN do
                tbl[i] = 0
            end
        end

        for note = 1, tN do
            for frame = tF+1, M.totFrame do
                self.multiPressTime[frame*tN + note] = M.toBeat(frame/M.framerate) - (self.source.time[note] or -1)
                self.multiPressNorm[frame*tN + note] = self.multiPressTime[frame*tN + note] / (self.source.length[note] or 1)
                self.multiWasPressed[frame*tN + note] = self.multiPressNorm[frame*tN + note] >= 0
                self.multiWasReleased[frame*tN + note] = self.multiPressNorm[frame*tN + note] >= 1
                self.multiIsPressed[frame*tN + note] = self.multiWasPressed[frame*tN + note] and (not self.multiWasReleased[frame*tN + note])
            end
        end

        self.totalFrame = M.totFrame
    end

end

---Creates new blank MultiPlayState. Also stores it in M.bufferPlayState.
---@param source MidiNotes          the source MidiNotes object the PlayState will update from.
---@param instance? table           if given, turns that table into MultiPlayState instead of making new object
---@return MultiPlayState instance  MultiPlayState
function M.MultiPlayState.new(source, instance)
    instance = instance or {}
    M.bufferPlayState[source.filePath] = instance
    setmetatable(instance, M.MultiPlayState)
    instance.source = source
    instance.totalNotes = #instance.source.time
    instance.totalFrame = 0
    instance.latestAtFrame = {}
    instance.multiPressTime = {}
    instance.multiPressNorm = {}
    instance.multiWasPressed = {}
    instance.multiWasReleased = {}
    instance.multiIsPressed = {}
    instance:extend()
    return instance
end

---Update the MultiPlayState
---@param noteIndex? number noteIndex to read; defaults to the latest note.
---@param force? boolean    If true, will always update; else, only update when frame changed.
function M.MultiPlayState:update(noteIndex, force)
    noteIndex = noteIndex or self.latestAtFrame[M.curFrame+1]
    self:extend()
    if(self.currentFrame ~= M.curFrame or force) then
        self.noteIndex = noteIndex
        self.currentFrame = M.curFrame
        self.pressTime = self:getNote("multiPressTime", noteIndex, M.curFrame)
        self.pressNorm = self:getNote("multiPressNorm", noteIndex, M.curFrame)
        self.wasPressed = self:getNote("multiWasPressed", noteIndex, M.curFrame)
        self.wasReleased = self:getNote("multiWasReleased", noteIndex, M.curFrame)
        self.isPressed = self:getNote("multiIsPressed", noteIndex, M.curFrame)
    end
        
end

---@class SequencedImage        Used to store some properties of sequenced images.
---@field pathGeneral string    file path without the numbers and file extension.
---@field extensionIndx integer the index where fiele extension begins
---@field fileExtension string  file extension including period
---@field is0Filled boolean     whether the sequenced image index fill higher unused digit with 0 or not
---@field totalDigits integer   used when is0Filled is true. Total digits used to fill.
---@field startFrame integer    the first frame of the sequence found
---@field finalFrame integer    final frame of the sequence found; hard cap for loopEnd.
---@field loopStart integer     once the image overshoots the loopEnd, starts looping here.
---@field loopEnd integer       frame after this frame will loop back to loopStart.
---@field modulo integer        the length of loop. loopEnd - loopStart + 1
M.SequencedImage = {
    pathGeneral = "",
    extensionIndx = 1,
    fileExtension = ".png",
    is0Filled = false,
    totalDigits = 0,
    startFrame = 1,
    finalFrame = 2,
    loopStart = 1,
    loopEnd = 2,
    modulo = 2
}
M.SequencedImage.__index = M.SequencedImage

---Creates new blank SequencedImage instance. Also stores it in bufferPlayState.
---@param filePath string           file path used as index and read from.
---@param instance? table           if given, turns that table into RawNoteEvents instead of making new object
---@return SequencedImage instance  used to store some properties of filepath
function M.SequencedImage.new(filePath, instance)
    instance = instance or {}
    M.bufferSeqImage[filePath] = instance
    setmetatable(instance, M.SequencedImage)
    return instance
end

---Depending on how the Sequenced Image is numbered, returns appropriate file path to load the given frame.
---@param frame integer         the number of the frame to load.
---@return string completePath  the complete filepath to load.
function M.SequencedImage:getCompletePath(frame)
    local string = self.pathGeneral
    if(self.is0Filled and frame > 9) then
        string = string..string.rep("0", self.totalDigits - tostring(frame):len())
    end
    return string..frame..self.fileExtension
end

---Starting with start frame, opens image one by one. Records & returns the final frame where load was successful.
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

---Gets an instance of SequencedImage at given path. Creates one if they don't exist.
---@param filePath string           file path used as index and read from.
---@param loopStart integer         once the image overshoots the loopEnd, starts looping here.
---@param loopEnd integer           frame after this frame will loop back to loopStart.
---@param forceReset? boolean       if true, deletes the SequencedImage object to recreate it.
---@return SequencedImage seqImage  appropraiate instance of object created.
function M.SequencedImage.getInstance(filePath, loopStart, loopEnd, forceReset)
    local seqImage = M.bufferSeqImage[filePath]

    if(forceReset or not seqImage) then
        seqImage = M.SequencedImage.new(filePath)
        local strStartFrame = ""
        seqImage.extensionIndx, _, strStartFrame, seqImage.fileExtension = filePath:find("(%d+)(%.[^%.]+)$")
        if(not seqImage.extensionIndx) then
            obj.load("text", "Invalid Sequenced Image!\n読み込んだファイルは連番画像ではありません！")
            obj.draw()
            return seqImage
        end
        seqImage.pathGeneral = filePath:sub(1,seqImage.extensionIndx-1)
        seqImage.startFrame = tonumber(strStartFrame) or 1
        seqImage.is0Filled =(strStartFrame == tostring(seqImage.startFrame))

        if(seqImage.is0Filled) then
            seqImage.totalDigits = strStartFrame:len()
        end

        seqImage.finalFrame = seqImage:findFinalFrame()
    end

    seqImage.loopStart  = math.max(loopStart, seqImage.startFrame)
    seqImage.loopEnd    = math.min(seqImage.finalFrame, math.max(loopStart, loopEnd))
    seqImage.modulo     = seqImage.loopEnd - seqImage.loopStart + 1

    return seqImage
end

---Use pressTime and playSpeed to get the frame and appropriate complete path.
---@param pressTime number      the time in beats since the note was pressed. 
---@param playSpeed number      the play speed of animation
---@return string completePath  Complete path to be used by obj.load()
---@return integer frame        the number of the loaded frame
function M.SequencedImage:update(pressTime, playSpeed)
    local frame = self.startFrame + math.max(0, math.floor(M.unBeat(pressTime)*playSpeed/100*obj.framerate))
    frame = math.min(frame, (frame-self.loopStart)%self.modulo+self.loopStart)
    return self:getCompletePath(frame), frame
end

--List of easing functions
M.ease = {
    --linear
    ---@param x number          progress of animation. Assumes it starts at 0 and ends at 1.
    ---@param m number          Magnitude used in some of easing.
    ---@return number progress  progress eased by appropraiate function. If index%3 is 2, it is a bounce: achieves 1 at middle and 0 at either end.
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
---@param x number          progress of animation. Assumes it starts at 0 and ends at 1.
---@param m number          Magnitude used in some of easing.
---@param index integer     The index of easing function.
---@return number progress  progress eased by appropraiate function. If index%3 is 2, it is a bounce: achieves 1 at middle and 0 at either end.
function M.ease.force(x, m, index)
    return M.ease[index](math.max(0, math.min(1, x)),m)
end

---Converts time into beat.
---@param time timeSecond   time in seconds
---@return timeBeat time    time in beats
function M.toBeat(time)
    return time*M.bpm/60
end

---Inverse of above.
---@param time timeBeat     time in beats
---@return timeSecond time  time in seconds
function M.unBeat(time)
    return time*60/M.bpm
end

---Extracts sign.
---@param num number    number
---@return number sign  sign of the number
function M.sign(num)
    return (num>0) and 1 or ((num<0) and -1 or 0)
end

return M