debug_print("Loading midi2Otomad.lua")

local O = {}

O.bufferSeqImage    = {} --Save information about sequenced images.
O.bufferPlayState   = {} --Saves PlayState wtih file path as index. Is updated ev ery frame as animation changes.
--M.bufferLayerPath   = {} --Saves the path of MIDI loaded by M object on layer at index
O.bufferMisc        = {zoom = {}} --Other

O.MidiToAnimator =  require("library_M2O/midi2Animator")
O.MidiToAnalyzer = O.MidiToAnimator.MidiToAnalyzer

local L = O.MidiToAnimator.MidiToAnalyzer
local M = O.MidiToAnimator

return O