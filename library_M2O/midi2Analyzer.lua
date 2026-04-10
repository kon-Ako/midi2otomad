debug_print("Loading midi2Analyzer.lua")

local bit = require("bit")
local L = {}


---@alias bytesAsString string  The string read with io.open from MIDI file.

---@class ParsedNoteEvents           
---@field midiFormat integer    Format of MIDI. 0,1, or 2
---@field numTrack integer      Numbers of tracks loaded in MIDI
---@field isSMPTETime boolean   Whether the MIDI uses SMPTE time, which isn't supported by script.
---@field ppq integer           number of ticks in each quarter note
---@field track table           integer, the track the event is in
---@field deltaTime table       integer, the tick the event occurs since last event started
---@field absoluteTime table    integer, the tick the event occurs since the beginning of track
---@field status table          integer, the status of event
---@field channel table         integer, the channel the event is in
---@field note table            integer, the pitch of note event
---@field velocity table        integer, the velocity of note event
---@field totalEvents integer   total of events recorded in raw.
L.ParsedNoteEvents = {
    midiFormat = 0,
    numTrack = 1,
    isSMPTETime = false,
    track = {},
    deltaTime = {},
    absoluteTime = {},
    status = {},
    channel = {},
    note = {},
    velocity = {},
    totalEvents = 16
}
L.ParsedNoteEvents.__index = L.ParsedNoteEvents

---Creates new ParsedNoteEvents.
---@param instance? table               If given, turns that table into ParsedNoteEvents instead of making new object
---@return ParsedNoteEvents instance    ParsedNoteEvents with default values
function L.ParsedNoteEvents:new(instance)
    instance = instance or {}
    setmetatable(instance, self)
    instance.midiFormat = 0
    instance.numTrack = 1
    instance.isSMPTETime = false
    instance.track = {}
    instance.deltaTime = {}
    instance.absoluteTime = {}
    instance.status = {}
    instance.channel = {}
    instance.note = {}
    instance.velocity = {}
    instance.totalEvents = 16
    return instance
end

---@class MidiNotes             table of list of notes easily calculated by Animator    MIDIの音符の一覧。簡単に計算できる
---@field time table            start time of each note in events
---@field length table          the length of each note is in events
---@field track table           the track each note is in
---@field channel table         the channel each note is in
---@field note table            the pitch of each note
---@field notename table        (unimplemented) name of above
---@field velocity table        the velocity of each note
---@field trackEndTime table    length of each track; indices correspond to (track_number + 1) instead.
---@field loopAt integer        the largest value in trackEndTime
L.MidiNotes = {
    time = {},
    length = {},
    track = {},
    channel = {},
    note = {},
    notename = {},
    velocity = {},
    trackEndTime = {},
    loopAt = 8
}
L.MidiNotes.__index = L.MidiNotes

---Creates new MidiNotes.
---@param instance? table       If given, turns that table into MidiNotes instead of making new object
---@return MidiNotes instance   MidiNotes with default value
function L.MidiNotes:new(instance)
    instance = instance or {}
    setmetatable(instance, self)
    instance.time = {}
    instance.length = {}
    instance.track = {}
    instance.channel = {}
    instance.note = {}
    instance.notename = {}
    instance.velocity = {}
    instance.trackEndTime = {}
    instance.loopAt = 8
    return instance
end

---Write the contents of table as a string
---@param table table           table to read and explain as string
---@param isShowTypes? boolean  whether to show the type of value instead of the value itself
---@param strH? string          Starting statement
---@param str1? string          before index
---@param str2? string          between index and value
---@param str3? string          after value
---@param strT? string          Final statement
---@param isList? boolean       Use ipairs() instead of pairs() if true
---@return string str           String that shows all the contents of table
function L.writeTableContents(table, isShowTypes, strH, str1, str2, str3, strT, isList)
    strH = strH or "Contents are: "
    str1 = str1 or "\n"
    str2 = str2 or " has "
    str3 = str3 or "."
    strT = strT or "\n----"

    local prs = isList and ipairs or pairs

    if(isShowTypes) then
        for k,v in prs(table) do
            strH = strH..str1..k..str2..type(v)..str3
        end
    else
        for k,v in prs(table) do
            strH = strH..str1..k..str2..v..str3
        end
    end

    strH = strH..strT
    return strH
end

L.noteNames = {"C-1", "C#-1", "D-1", "D#-1", "E-1", "F-1", "F#-1", "G-1", "G#-1", "A-1", "A#-1", "B-1", 
"C0", "C#0", "D0", "D#0", "E0", "F0", "F#0", "G0", "G#0", "A0", "A#0", "B0", 
"C1", "C#1", "D1", "D#1", "E1", "F1", "F#1", "G1", "G#1", "A1", "A#1", "B1", 
"C2", "C#2", "D2", "D#2", "E2", "F2", "F#2", "G2", "G#2", "A2", "A#2", "B2", 
"C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3", 
"C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", 
"C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5", 
"C6", "C#6", "D6", "D#6", "E6", "F6", "F#6", "G6", "G#6", "A6", "A#6", "B6", 
"C7", "C#7", "D7", "D#7", "E7", "F7", "F#7", "G7", "G#7", "A7", "A#7", "B7", 
"C8", "C#8", "D8", "D#8", "E8", "F8", "F#8", "G8", "G#8", "A8", "A#8", "B8", 
"C9", "C#9", "D9", "D#9", "E9", "F9", "F#9", "G9"
}
---Get note name
---@param note integer      The pitch
---@return string noteName  The pitch as string
function L.noteNames:getNoteName(note)
    return (self[note%128+1])
end

---Read the string as byte
---@param string bytesAsString  the string to read as if it is list of bytes
---@param start integer         the index to start reading
---@param len integer           the length of bytes read
---@return integer byte         number read
---@return integer index        index after the read bytes
function L.readByte(string, start, len)
    local num = 0
    for i=0, len-1 do
        num = num*256 + string:byte(start+i)
    end
    return num, start + len
end

---Determines whether the number is Variable Length Quantity
---@param num integer       the number to read
---@return boolean isVLQ    whether it is VLQ or not
---@return integer value    the value interpreted as VLQ
function L.isVLQ(num)
    return (false or (num>=128)), num%128
end

---Given the position is VLQ, reads the byte until it is not VLQ.
---@param string bytesAsString  string of binary
---@param start integer         the starting index to read from
---@return integer binary       The binary number read
---@return integer index        index after the datas that are combined as VLQ
function L.readVLQ(string, start)
    local bool, num, digit = true, 0, 0
    while (bool) do
        bool, digit = L.isVLQ(string:byte(start))
        num = num*128 + digit
        start = start + 1
    end
    return num, start
end

---@param pathMidi string           the path of MIDI to read.   MIDIのファイルパス
---@return bytesAsString strMIDI    MIDI as string of binary.   迫真!バイナリのStringと化したMIDI先輩
function L.midiOpenAsString(pathMidi)
    local str = ""
    local file = assert(io.open(pathMidi, "rb"))
    if (not file) then
        str = "ERROR!"
        debug_print("MIDI load failed!")
    else
        str = file:read("*all")
        debug_print("MIDI load success!")
    end
    if (str:sub(1,4) ~= "MThd") then
        str = "NOT A VALID MIDI!"
        debug_print("MIDI is in a wrong format!")
    end
    file:close()
    debug_print("Successfully closed!")
    return str
end

L.bufferParsedNoteEvents = L.ParsedNoteEvents:new()

---Decode string extracted from MIDI into table of note events. 
---@param string bytesAsString          MIDI as string of binary.       迫真!バイナリのStringと化したMIDI先輩
---@param instance? ParsedNoteEvents    A cache table to update
---@return ParsedNoteEvents tblMIDI     MIDI deconstructed into table.  テーブルとして解体したMIDI
function L.midiDecode(string, instance)
    local dict = L.ParsedNoteEvents:new(instance)
    local currentSize = string:byte(7)*256 + string:byte(8)
    local curIndx = 1
    local pos = currentSize + 9
    local currentData = 0
    local cumulativeTime = 0
    local beganMtrk = 0 --the byte where currently reading track began, to make sure we don't overshoot
    local runningStatus = 0x90
    local systemEventLength = 0
    local metaType = 0
    dict.midiFormat = string:byte(10)
    dict.numTrack = string:byte(12)
    dict.isSMPTETime = bit.rshift(string:byte(13), 7) == 1
    dict.ppq = string:byte(13)*256 + string:byte(14)

    for trackIndex=0, dict.numTrack-1 do
        pos = string:find("MTrk", pos)
        if(not pos) then
            debug_print("No more MTrk found")
            break
        end
        --Read the size of the track, and put the pointer to the track's array
        currentSize, pos  = L.readByte(string, pos+4, 4)
        beganMtrk = pos - 1
        while(pos < currentSize + beganMtrk) do
            dict.track[curIndx] = trackIndex
            --Record Delta Time
            currentData, pos = L.readVLQ(string, pos)
            cumulativeTime = cumulativeTime + currentData
            dict.deltaTime[curIndx] = currentData
            dict.absoluteTime[curIndx] = cumulativeTime
            --Record Status
            currentData = string:byte(pos)
            if(currentData >= 128) then
                dict.status[curIndx] = currentData
                runningStatus = currentData
                pos = pos + 1
            else
                dict.status[curIndx] = runningStatus
            end

            if(dict.status[curIndx] >= 0xC0 and dict.status[curIndx] < 0xE0) then
                --Execute analysis on Program Change / Channel Aftertouch
                dict.channel[curIndx] = (dict.status[curIndx])%16
                dict.note[curIndx] = string:byte(pos)
                pos = pos + 1
            elseif(dict.status[curIndx] < 0xF0) then
                --Execute analysis on Basic MIDI Note Event
                --Record Channel
                dict.channel[curIndx] = (dict.status[curIndx])%16
                --Record Note
                dict.note[curIndx] = string:byte(pos)
                pos = pos + 1
                --Record Velocity
                dict.velocity[curIndx] = string:byte(pos)
                pos = pos + 1
            elseif(dict.status[curIndx] < 0xFF) then
                --Execute analysis on Common System Event
                systemEventLength, pos = L.readVLQ(string ,pos)
                dict.note[curIndx] = string:sub(pos, pos + systemEventLength - 1)
                pos = pos + systemEventLength
            else
                --Execute analysis on Meta Event
                metaType = string:byte(pos)
                dict.note[curIndx] = metaType
                pos = pos + 1
                systemEventLength, pos = L.readVLQ(string ,pos)
                dict.velocity[curIndx] = string:sub(pos, pos + systemEventLength - 1)
                pos = pos + systemEventLength
            end
            curIndx = curIndx + 1
        end

        cumulativeTime = 0
    end

    dict.totalEvents = curIndx

    return dict
end

L.bufferMidiNotes = L.MidiNotes:new()
L.bufferActiveNotes = {}    --temporary list used by L.midiNoteDecode for notes that are started (eventType == 9) yet not ended (eventType == 8)

---@param dict ParsedNoteEvents MIDI deconstructed into table.  テーブルとして解体したMIDI
---@param instance? MidiNotes   A buffer table to update
---@return MidiNotes instance   table of lists of notes easily calculated by Animator   MIDIの音符の一覧。簡単に計算できる
function L.midiNoteDecode(dict, instance)
    instance = instance or L.MidiNotes:new()
    local ind, finishInd = 1, 1
    local eventType, curTk, curCh, curNt, curVl, curAT, key = 9, 0, 0, 0, 0, 0, ""

    for k,v in ipairs(dict.status) do
        eventType = bit.rshift(v, 4)
        curTk = dict.track[k] or curTk
        curCh = dict.channel[k] or curCh
        curNt = dict.note[k] or curNt
        curVl = dict.velocity[k] or curVl
        curAT = dict.absoluteTime[k]/dict.ppq or curAT

        if(eventType == 9) then
            key = string.format("%d_%d_%d", curTk, curCh, curNt)
            instance.time[ind] = curAT
            instance.track[ind] = curTk
            instance.channel[ind] = curCh
            instance.note[ind] = curNt
            instance.notename[ind] = L.noteNames:getNoteName(curNt)
            instance.velocity[ind] = curVl

            L.bufferActiveNotes[key] = ind
            ind = ind + 1
        elseif(eventType == 8 or ((eventType == 9) and (dict.velocity[k] == 0))) then
            key = string.format("%d_%d_%d", curTk, curCh, curNt)
            finishInd = L.bufferActiveNotes[key]
            if finishInd then
                instance.length[finishInd] = (dict.absoluteTime[k]/dict.ppq) - instance.time[finishInd]
                L.bufferActiveNotes[key] = nil
            end
        elseif(eventType == 0xF) then
            if((v == 0xFF) and curNt == 0x2F) then
                instance.trackEndTime[curTk+1] = curAT
            end
        end

    end

    for k,v in ipairs(instance.trackEndTime) do
        instance.loopAt = math.max(instance.loopAt, v)
    end

    return instance
end

---@param pathMidi bytesAsString    the file path for MIDI to load 読み込むMIDIのファイルパス
---@param instance? MidiNotes       the table to write the data in
---@return MidiNotes rym            data of rhythm that we could easily interpret  抽出したデータをわかりやすく作り直したもの。
function L.midiToRhythm(pathMidi, instance)
    local string = L.midiOpenAsString(pathMidi)
    local dict = L.midiDecode(string)
    local rym = L.midiNoteDecode(dict, instance)
    return rym
end

return L