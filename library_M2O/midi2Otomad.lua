debug_print("Loading midi2Otomad.lua")

local O = {}

O.bufferSeqImage    = {} --Save information about sequenced images.
O.bufferPlayState   = {} --Saves PlayState wtih file path as index. Is updated ev ery frame as animation changes.
--M.bufferLayerPath   = {} --Saves the path of MIDI loaded by M object on layer at index
O.bufferMisc        = {zoom = {}} --Other

O.MidiToAnimator = require("library_M2O/midi2Animator")
O.MidiToAnalyzer = O.MidiToAnimator.MidiToAnalyzer

local L = O.MidiToAnimator.MidiToAnalyzer
local M = O.MidiToAnimator

---Returns the PlayState out given path
---@param pathMidi? string      Path to the MIDI originally loaded and read from
---@return PlayState N          PlayState corresponding to given path
---@deprecated
function O.loadBufferLatestNote(pathMidi)
    debug_print("Doing O.loadBufferLatestNote for "..pathMidi)
    if((not pathMidi) or pathMidi == "") then
        pathMidi = M.bufferLayerPath[obj.layer]
    end
    local N = M.bufferPlayState[pathMidi]
    if(not N) then
        debug_print("AAAAAAAAAAAAAAAAAAAAAAAA")
        obj.load("text", "selected MIDI is not loaded!\n選択したMIDIが読み込まれていません！")
        N = M.PlayState.getInstance(pathMidi)
    end
    return N
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
---@param pathMidi? string          Path to the MIDI originally loaded and read from
---@return PlayState instance       PlayState with updated animation properties
function O.saveAnim(length, isNorm, delayIndex, easing, magnitude, isDecaying, isSwitching, isAlternating, pathMidi)
    debug_print("saveAnim began")
    local N = O.loadBufferLatestNote(pathMidi)
    N.progressIndex = N.noteIndex + delayIndex
    isDecaying = (isDecaying + isSwitching*N.progressIndex)%2
    N.progressSign = 1-2*(isAlternating*N.progressIndex%2)
    N.progress = ((length == 0) and 1) or (isNorm and N.pressNorm or N.pressTime)/length --if length is 0, finish immediately; else, N.progress is squished by length
    N.progressEased = (isDecaying+(1-2*isDecaying)*(M.ease.force(N.progress, magnitude, easing)))*N.progressSign
    return N
end

return O