debug_print("Loading midi2Otomad.lua")

local O = {}

O.CacheMidi         = {}
O.CacheNotePress    = {}
O.CacheLayer        = {path = {}}
O.CacheMisc         = {zoom = {}}

O.MidiToAnalyzer = require("library_M2O/midi2Analyzer")
O.MidiToAnimator = require("library_M2O/midi2Animator")

local L = O.MidiToAnalyzer
local M = O.MidiToAnimator

---@param pathMidi string   Decode MIDI file at the path, stores it in a cache only once. Will not read if cache already exists.
---@param resetThis int     Deletes the cache to re-read the MIDI file.
function O.saveCacheMidi(pathMidi, resetThis)
    if(resetThis == 1) then
        O.CacheMidi[pathMidi] = nil
    end

    if(not (O.CacheMidi[pathMidi])) then
        O.CacheMidi[pathMidi] = L.midiToRhythm(pathMidi)
        debug_print("Scanned MIDI at: "..pathMidi)
    end
end 

function O.saveCacheLatestNote(currentTime, noteEvents, path)

    if((not path) or path == "") then
        path = obj.layer
    else
        O.CacheLayer.path[obj.layer] = path
    end

    if(not (O.CacheNotePress[path])) then
        O.CacheNotePress[path] = { index = 1, sustain = 0, sustNorm = 0, isPressed = false}
    end
    local lastIndexRead = O.CacheNotePress[path].index
    local a,b,c,d = M.playLatestNote(currentTime, noteEvents, lastIndexRead)
    O.CacheNotePress[path].index = a
    O.CacheNotePress[path].sustain = b
    O.CacheNotePress[path].sustNorm = c
    O.CacheNotePress[path].isPressed = d
end

function O.loadCacheLatestNote(path)
    if((not path) or path == "") then
        path = O.CacheLayer.path[obj.layer]
    end
    local N = O.CacheNotePress[path]
    if(not N) then
        obj.load("text", "selected MIDI is not loaded!\n選択したMIDIが読み込まれていません！")
        N = {index = 0, sustain = 0, sustNorm = 0, isPressed = false}
    end
    return N.index, N.sustain, N.sustNorm, N.isPressed
end

return O