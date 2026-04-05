debug_print("Loading midi2Otomad.lua")

local O = {}

O.cacheMidi         = {}
O.bufferNotePress   = {}
O.bufferLayer       = {path = {}}
O.bufferMisc        = {zoom = {}}

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
        O.cacheMidi[pathMidi] = L.midiToRhythm(pathMidi)
        debug_print("Scanned MIDI at: "..pathMidi)
    end
end 

---comment
---@param currentTime timeBeat
---@param noteEvents MidiNotes
---@param path string
function O.saveBufferLatestNote(currentTime, noteEvents, path)

    if((not path) or path == "") then
        path = obj.layer
    else
        O.bufferLayer.path[obj.layer] = path
    end

    if(not (O.bufferNotePress[path])) then
        O.bufferNotePress[path] = { index = 1, sustain = 0, sustNorm = 0, isPressed = false}
    end
    local lastIndexRead = O.bufferNotePress[path].index
    local a,b,c,d = M.playLatestNote(currentTime, noteEvents, lastIndexRead)
    O.bufferNotePress[path].index = a
    O.bufferNotePress[path].sustain = b
    O.bufferNotePress[path].sustNorm = c
    O.bufferNotePress[path].isPressed = d
end

function O.loadBufferLatestNote(path)
    if((not path) or path == "") then
        path = O.bufferLayer.path[obj.layer]
    end
    local N = O.bufferNotePress[path]
    if(not N) then
        obj.load("text", "selected MIDI is not loaded!\n選択したMIDIが読み込まれていません！")
        N = {index = 0, sustain = 0, sustNorm = 0, isPressed = false}
    end
    return N.index, N.sustain, N.sustNorm, N.isPressed
end

return O