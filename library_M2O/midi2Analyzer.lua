local L = {}

function L.writeTableContents(table, isShowTypes, strH, str1, str2, str3, strT)
    strH = strH or "Contents are: "
    str1 = str1 or "\n"
    str2 = str2 or " has "
    str3 = str3 or "."
    strT = strT or "\n----"

    if(isShowTypes) then
        for k,v in pairs(table) do
            strH = strH..str1..k..str2..type(v)..str3
        end
    else
        for k,v in pairs(table) do
            strH = strH..str1..k..str2..v..str3
        end
    end

    strH = strH..strT
    return strH
end

function L.writeListContents(table, isShowTypes, strH, str1, str2, str3, strT)
    strH = strH or "Contents are: "
    str1 = str1 or "\n#"
    str2 = str2 or " has "
    str3 = str3 or "."
    strT = strT or "\n----"

    if(isShowTypes) then
        for k,v in ipairs(table) do
            strH = strH..str1..k..str2..type(v)..str3
        end
    else
        for k,v in ipairs(table) do
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
"C9", "C#9", "D9", "D#9", "E9", "F9", "F#9", "G9", getName = function(thisAr, index) return thisAr[index+1] end
}

---@return int      the number read
---@return int      the index after the read bytes
function L.readByte(string, start, len)
    local num = 0
    for i=0, len-1 do
        num = num*256 + string:byte(start+i)
    end
    return num, start + len
end

function L.isVLQ(num)
    return (false or (num>=128)), num%128
end

---@param string String     string of binary
---@param start int         the starting index to read from
---@return int              the result as int
---@return int              the index after the VLQ as int
function L.readVLQ(string, start)
    local bool, num, digit = true, 0, 0
    while (bool) do
        bool, digit = L.isVLQ(string:byte(start))
        num = num*128 + digit
        start = start + 1
    end
    return num, start
end

---@param path String   the path of MIDI to read.   MIDIのファイルパス
---@return String       MIDI as string of binary.   迫真!バイナリのStringと化したMIDI先輩
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

---@param string String     MIDI as string of binary.       迫真!バイナリのStringと化したMIDI先輩
---@return dictionary       MIDI deconstructed into table.  テーブルとして解体したMIDI
function L.midiDecode(string)
    local dict = {}
    local currentSize = string:byte(7)*256 + string:byte(8)
    local curIndx = 1
    local pos = currentSize + 9
    local currentData = 0
    local cumulativeTime = 0
    local beganMtrk = 0
    local runningStatus = 0x90
    local systemEventLength = 0
    local metaType = 0
    dict.midiFormat = string:byte(10)
    dict.numTrack = string:byte(12)
    dict.isSMPTETime = (bit.rshift(string:byte(13), 7) == 1)
    dict.ppq = string:byte(13)*256 + string:byte(14)

    dict.raw = {track = {}, deltaTime = {}, absoluteTime = {}, status = {}, channel = {}, note = {}, velocity = {}}

    for trackIndex=0, dict.numTrack-1 do
        debug_print("Reading track # "..trackIndex)
        pos = string:find("MTrk", pos)
        if(not pos) then
            debug_print("No more MTrk found")
            break
        end
        --Read the size of the track, and put the pointer to the track's array
        currentSize, pos  = L.readByte(string, pos+4, 4)
        beganMtrk = pos - 1
        while(pos < currentSize + beganMtrk) do
            dict.raw.track[curIndx] = trackIndex
            --Record Delta Time
            currentData, pos = L.readVLQ(string, pos)
            cumulativeTime = cumulativeTime + currentData
            dict.raw.deltaTime[curIndx] = currentData
            dict.raw.absoluteTime[curIndx] = cumulativeTime
            --Record Status
            currentData = string:byte(pos)
            if(currentData >= 128) then
                dict.raw.status[curIndx] = currentData
                runningStatus = currentData
                pos = pos + 1
            else
                dict.raw.status[curIndx] = runningStatus
            end

            if(dict.raw.status[curIndx] >= 0xC0 and dict.raw.status[curIndx] < 0xE0) then
                --Execute analysis on Program Change / Channel Aftertouch
                dict.raw.channel[curIndx] = (dict.raw.status[curIndx])%16
                dict.raw.note[curIndx] = string:byte(pos)
                pos = pos + 1
            elseif(dict.raw.status[curIndx] < 0xF0) then
                --Execute analysis on Basic MIDI Note Event
                --Record Channel
                dict.raw.channel[curIndx] = (dict.raw.status[curIndx])%16
                --Record Note
                dict.raw.note[curIndx] = string:byte(pos)
                pos = pos + 1
                --Record Velocity
                dict.raw.velocity[curIndx] = string:byte(pos)
                pos = pos + 1
            elseif(dict.raw.status[curIndx] < 0xFF) then
                --Execute analysis on Common System Event
                systemEventLength, pos = L.readVLQ(string ,pos)
                dict.raw.note[curIndx] = string:sub(pos, pos + systemEventLength - 1)
                pos = pos + systemEventLength
            else
                --Execute analysis on Meta Event
                metaType = string:byte(pos)
                dict.raw.note[curIndx] = metaType
                pos = pos + 1
                systemEventLength, pos = L.readVLQ(string ,pos)
                dict.raw.velocity[curIndx] = string:sub(pos, pos + systemEventLength - 1)
                pos = pos + systemEventLength
            end
            curIndx = curIndx + 1
        end

        cumulativeTime = 0
    end

    dict.totalEvents = curIndx

    return dict
end

---@param dict dictionary   MIDI deconstructed into table.  テーブルとして解体したMIDI
---@return dictionary       dictionary of note events easily read by player
function L.midiNoteDecode(dict)
    local noteD= { time = {}, length = {}, track = {}, channel = {}, note = {}, notename = {}, velocity = {}, trackEndTime = {}, loopAt = 1}
    local R = dict.raw
    local ind, finishInd = 1, 1
    local activeNotes = {}
    local eventType, curTk, curCh, curNt, curVl, curAT, key = 9, 0, 0, 0, 0, 0, ""

    for k,v in ipairs(R.status) do
        eventType = bit.rshift(v, 4)
        curTk = R.track[k] or curTk
        curCh = R.channel[k] or curCh
        curNt = R.note[k] or curNt
        curVl = R.velocity[k] or curVl
        curAT = R.absoluteTime[k]/dict.ppq or curAT

        if(eventType == 9) then
            key = string.format("%d_%d_%d", curTk, curCh, curNt)
            noteD.time[ind] = curAT
            noteD.track[ind] = curTk
            noteD.channel[ind] = curCh
            noteD.note[ind] = curNt
            --noteD.notename[k] = L.noteNames[129](L.noteNames, noteD.note[k])
            noteD.velocity[ind] = curVl

            activeNotes[key] = ind
            ind = ind + 1
        elseif(eventType == 8 or ((eventType == 9) and (R.velocity[k] == 0))) then
            key = string.format("%d_%d_%d", curTk, curCh, curNt)
            finishInd = activeNotes[key]
            if finishInd then
                noteD.length[finishInd] = (R.absoluteTime[k]/dict.ppq) - noteD.time[finishInd]
                activeNotes[key] = nil
            end
        elseif(eventType == 0xF) then
            if((v == 0xFF) and curNt == 0x2F) then
                noteD.trackEndTime[curTk] = curAT
            end
        end

    end

    for k,v in ipairs(noteD.trackEndTime) do
        noteD.loopAt = math.max(noteD.loopAt, v)
    end

    return noteD
end


---@param pathMidi string   the file path for MIDI to load 読み込むMIDIのファイルパス
---@return dictionary       data of rhythm that Lua could easily interpret  抽出したデータをわかりやすく作り直したもの。
function L.midiToRhythm(pathMidi)
    local dict = {}
    local rym = {}
    local string = L.midiOpenAsString(pathMidi)
    dict = L.midiDecode(string)
    rym = L.midiNoteDecode(dict)
    return rym
end

return L