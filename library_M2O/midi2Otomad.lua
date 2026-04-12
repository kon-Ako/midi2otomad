debug_print("Loading midi2Otomad.lua")

local O = {}

O.cacheMidi         = {} --Save MidiNotes with file path as index.
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
function O.saveCacheMidi(pathMidi, resetThis)
    if(resetThis == 1) then
        O.cacheMidi[pathMidi] = nil
    end

    if(not (O.cacheMidi[pathMidi])) then
        O.bufferLayerPath[obj.layer] = pathMidi
        O.cacheMidi[pathMidi] = L.midiToRhythm(pathMidi)
        debug_print("Scanned MIDI at: "..pathMidi)
    end
end

---Updates or creates PlayData at the given path. Executed every frame of M2O objects.
---@param currentTime timeBeat  time in beats
---@param listNotes MidiNotes   list of notes, decoded
---@param pathMidi? string      The path of midis
function O.saveBufferLatestNote(currentTime, listNotes, pathMidi)

    if((not pathMidi) or pathMidi == "") then
        pathMidi = O.bufferLayerPath[obj.layer]
    else
        O.bufferLayerPath[obj.layer] = pathMidi
    end

    if(not (O.bufferPlayData[pathMidi])) then
        O.bufferPlayData[pathMidi] = M.PlayData:new()
    end
    local lastIndexRead = O.bufferPlayData[pathMidi].index
    local a,b,c,d = M.playLatestNote(currentTime, listNotes, lastIndexRead, O.bufferPlayData[pathMidi])
end

---Read the PlayNote at given path
---@param pathMidi string       Path to the MIDI originally loaded and read from
---@return integer index        index of the note the data was taken from.
---@return integer sustain      the time since the note started was pressed. negative if it is upcoming note.
---@return integer sustNorm     the sustain, divided by the length of the note
---@return boolean isPressed    whether the note is currently active or not
function O.loadBufferLatestNote(pathMidi)
    if((not pathMidi) or pathMidi == "") then
        pathMidi = O.bufferLayerPath[obj.layer]
    end
    local N = O.bufferPlayData[pathMidi]
    if(not N) then
        obj.load("text", "selected MIDI is not loaded!\n選択したMIDIが読み込まれていません！")
        N = M.PlayData:new()
    end
    return N.index, N.sustain, N.sustNorm, N.isPressed
end

return O