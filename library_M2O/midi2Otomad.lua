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
---@param currentTime timeBeat
---@param noteEvents MidiNotes
---@param path string
function O.saveBufferLatestNote(currentTime, noteEvents, path)

    if((not path) or path == "") then
        path = O.bufferLayerPath[obj.layer]
    else
        O.bufferLayerPath[obj.layer] = path
    end

    if(not (O.bufferPlayData[path])) then
        O.bufferPlayData[path] = M.PlayData:new()
    end
    local lastIndexRead = O.bufferPlayData[path].index
    local a,b,c,d = M.playLatestNote(currentTime, noteEvents, lastIndexRead, O.bufferPlayData[path])
    --O.bufferPlayData[path].index = a
    --O.bufferPlayData[path].sustain = b
    --O.bufferPlayData[path].sustNorm = c
    --O.bufferPlayData[path].isPressed = d
end

function O.loadBufferLatestNote(path)
    if((not path) or path == "") then
        path = O.bufferLayerPath[obj.layer]
    end
    local N = O.bufferPlayData[path]
    if(not N) then
        obj.load("text", "selected MIDI is not loaded!\n選択したMIDIが読み込まれていません！")
        N = {index = 0, sustain = 0, sustNorm = 0, isPressed = false}
    end
    return N.index, N.sustain, N.sustNorm, N.isPressed
end

return O