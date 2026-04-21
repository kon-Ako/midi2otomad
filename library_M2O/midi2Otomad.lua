debug_print("Loading midi2Otomad.lua")

local O = {}

O.cacheMidi         = {} --Save MidiNotes with file path as index.
O.bufferSeqImage    = {} --Save information about sequenced images.
O.bufferPlayData    = {} --Saves PlayData wtih file path as index. Is updated ev ery frame as animation changes.
O.bufferLayerPath   = {} --Saves the path of MIDI loaded by M object on layer at index
O.bufferMisc        = {zoom = {}} --Other

O.MidiToAnalyzer = require("library_M2O/midi2Analyzer")
O.MidiToAnimator = require("library_M2O/midi2Animator")

local L = O.MidiToAnalyzer
local M = O.MidiToAnimator

---Loads, decodes, and extract notes from MIDI file at path. Stores the notes in a cache with the file path as key.
---@param pathMidi string       Decode MIDI file at the path, stores it in a cache only once. Will not read if cache already exists.
---@param resetThis? boolean    Deletes the cache to re-read the MIDI file.
---@return MidiNotes cache      The cache table of notes from MIDI at given path.
function O.saveCacheMidi(pathMidi, resetThis)
    if(resetThis == 1) then
        O.cacheMidi[pathMidi] = nil
    end

    if(not (O.cacheMidi[pathMidi])) then
        O.bufferLayerPath[obj.layer] = pathMidi
        O.cacheMidi[pathMidi] = L.midiToRhythm(pathMidi)
        debug_print("Scanned MIDI at: "..pathMidi)
    end

    return O.cacheMidi[pathMidi]
end

---Updates or creates PlayData at the given path. Executed every frame of M2O objects.
---@param currentTime timeBeat  time in beats
---@param listNotes MidiNotes   list of notes, decoded
---@param pathMidi? string      The path of midis
---@return PlayData instance    The updated PlayData table
function O.saveLatestNote(currentTime, listNotes, pathMidi)

    if((not pathMidi) or pathMidi == "") then
        pathMidi = O.bufferLayerPath[obj.layer]
    else
        O.bufferLayerPath[obj.layer] = pathMidi
    end

    if(not (O.bufferPlayData[pathMidi])) then
        O.bufferPlayData[pathMidi] = M.PlayData:new()
    end
    local lastIndexRead = O.bufferPlayData[pathMidi].index
    return M.playLatestNote(currentTime, listNotes, lastIndexRead, O.bufferPlayData[pathMidi])
end

---Returns the PlayData out given path
---@param pathMidi? string      Path to the MIDI originally loaded and read from
---@return PlayData N           PlayData corresponding to given path
function O.loadBufferLatestNote(pathMidi)
    if((not pathMidi) or pathMidi == "") then
        pathMidi = O.bufferLayerPath[obj.layer]
    end
    local N = O.bufferPlayData[pathMidi]
    if(not N) then
        obj.load("text", "selected MIDI is not loaded!\n選択したMIDIが読み込まれていません！")
        N = M.PlayData:new()
    end
    return N
end

---Reprocess the sustain of note based on information from track bar.
---@param length number             length of animation, in beats
---@param isNorm boolean            if true, anim uses sustNorm instead of sustain
---@param delayIndex integer        index is calculated with this number added instead of actual number.
---@param easing integer            specifies which easing function is used
---@param magnitude number          magnitude of easing function
---@param isDecaying integer        0 or 1. If 1, animEased transition from 1→0 instead of 0→1
---@param isSwitching integer       0 or 1. If 1, animEased swtich between decay and grow every index.
---@param isAlternating integer     0 or 1. If 1, index is multiplied by -1 every other index.
---@param pathMidi? string          Path to the MIDI originally loaded and read from
---@return PlayData instance        PlayData with updated animation properties
function O.saveAnim(length, isNorm, delayIndex, easing, magnitude, isDecaying, isSwitching, isAlternating, pathMidi)
    local N = O.loadBufferLatestNote(pathMidi)
    N.animIndex = N.index + delayIndex
    isDecaying = (isDecaying + isSwitching*N.animIndex)%2
    N.animSign = 1-2*(isAlternating*N.animIndex%2)
    local anim = isNorm and N.sustNorm or N.sustain
    N.anim = (length == 0) and 1 or anim/length --if length is 0, finish immediately; else, N.anim is squished by length
    N.animEased = (isDecaying+(1-2*isDecaying)*(M.ease.force(N.anim, magnitude, easing)))*N.animSign
    return N
end

return O