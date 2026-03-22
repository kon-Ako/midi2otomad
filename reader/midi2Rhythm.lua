local M = {}

-- For Debug
local function printHex(num)
    debug_print(string.format("%x", num))
end

local function printPairs(dict)
    debug_print("\n----Starting printPairs----")
    for k,v in pairs(dict) do
        debug_print(k.." is "..type(v))
    end
    debug_print("----\n")
end

---@param dict dictionary   function reads the content of dict
local function printStrPairs(dict)
    debug_print("\n----Starting printStrPairs----")
    for k,v in pairs(dict) do
        if(type(v)=="string") then
            debug_print(k.." is Str: "..v)
        elseif(type(v)=="boolean") then
            if(v) then 
                debug_print(k.." was true")
            else
                debug_print(k.." was false")
            end
        else
            debug_print(k.." is type: "..type(v))
        end
    end
    debug_print("\n----\n")
end

local function printArrayContents(array)
    debug_print("\n----Starting printArrayContents----")
    local a = "{"
    for k,v in ipairs(array) do
        a = a..v..", "
    end
    debug_print(a:sub(1,-3).."}"..", Cardinality: "..#array)
end

local function printDictContents(array)
    debug_print("\n----\nStarting printDictContents\n----")
    local a = ""
    for k,v in pairs(array) do
        a = a..k.." has "..v.."\n"
    end
    debug_print(a)
end

M.noteNames = {"C-1", "C#-1", "D-1", "D#-1", "E-1", "F-1", "F#-1", "G-1", "G#-1", "A-1", "A#-1", "B-1", 
"C0", "C#0", "D0", "D#0", "E0", "F0", "F#0", "G0", "G#0", "A0", "A#0", "B0", 
"C1", "C#1", "D1", "D#1", "E1", "F1", "F#1", "G1", "G#1", "A1", "A#1", "B1", 
"C2", "C#2", "D2", "D#2", "E2", "F2", "F#2", "G2", "G#2", "A2", "A#2", "B2", 
"C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3", 
"C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", 
"C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5", 
"C6", "C#6", "D6", "D#6", "E6", "F6", "F#6", "G6", "G#6", "A6", "A#6", "B6", 
"C7", "C#7", "D7", "D#7", "E7", "F7", "F#7", "G7", "G#7", "A7", "A#7", "B7", 
"C8", "C#8", "D8", "D#8", "E8", "F8", "F#8", "G8", "G#8", "A8", "A#8", "B8", 
"C9", "C#9", "D9", "D#9", "E9", "F9", "F#9", "G9", }

---@return int      the number read
---@return int      the index after the read bytes
function M.readByte(string, start, len)
    local num = 0
    for i=0, len-1 do
        num = num*256 + string:byte(start+i)
    end
    return num, start + len
end

function M.isVLQ(num)
    return (false or (num>=128)), num%128
end

---@param string String     string of binary
---@param start int         the starting index to read from
---@return int              the result as int
---@return int              the index after the VLQ as int
function M.readVLQ(string, start)
    local bool, num, digit = true, 0, 0
    while (bool) do
        bool, digit = M.isVLQ(string:byte(start))
        num = num*128 + digit
        start = start + 1
    end
    return num, start
end

---@param path String   the path to MIDI to read.    
---@return String       MIDI as string of binary.   迫真!バイナリのStringと化したMIDI先輩
function M.midiOpenAsString(pathMidi)
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

---@param string String     MIDI as string of binary.   迫真!バイナリのStringと化したMIDI先輩
---@return array            array of bytes
function M.midiStringToBinArray(string)
    local bnAry = {}
    for i=1, string:len() do
        bnAry[i] = string:byte(i)
        --printHex(bnAry[i])
    end
    return bnAry
end

---@param string String     MIDI as string of binary.   迫真!バイナリのStringと化したMIDI先輩
---@return dictionary       easily readable properties of MIDI
function M.midiDecode(string)
    local dict = {}
    local currentSize = string:byte(7)*256 + string:byte(8)
    local currentIndex = currentSize + 9
    local currentTime = 0
    local currentData = 0
    local beganMtrk = 0
    local runningStatus = 0x90
    dict.midiFormat = string:byte(10)
    dict.numTrack = string:byte(12)
    dict.isSMPTETime = (bit.rshift(string:byte(13), 7) == 1)
    dict.ppq = string:byte(13)*256 + string:byte(14)

    dict.raw = {track = {}, deltaTime = {}, status = {}, channel = {}, note = {}, velocity = {}}

    for i=0, dict.numTrack-1 do
        debug_print("Reading track # "..(i-1))
        currentIndex = string:find("MTrk", currentIndex)
        --Read the size of the track, and put the pointer to the track's array
        currentSize, currentIndex  = M.readByte(string, currentIndex+4, 4)
        beganMtrk = currentIndex - 1
        while(currentIndex < currentSize + beganMtrk) do
            table.insert(dict.raw.track, i)
            --Record Delta Time
            currentData, currentIndex = M.readVLQ(string, currentIndex)
            table.insert(dict.raw.deltaTime, currentData)
            --Record Status
            currentData = string:byte(currentIndex)
            currentIndex = currentIndex + 1
            if(currentData >= 128) then
                table.insert(dict.raw.status, currentData)
                runningStatus = currentData
            else
                table.insert(dict.raw.status, runningStatus)
            end
            --Record Channel
            table.insert(dict.raw.channel, (dict.raw.status[#dict.raw.status])%16)
            --Record Note
            table.insert(dict.raw.note, string:byte(currentIndex))
            currentIndex = currentIndex + 1
            --Record Velocity
            table.insert(dict.raw.velocity, string:byte(currentIndex))
            currentIndex = currentIndex + 1
        end
    end

    return dict
end

---@param array array   Raw datas extracted from M.midiDecode()
---@return dictionary       
function M.midiNoteDecode(array)
    local dict= {}
    return dict
end


---@param pathMidi string   the file path for MIDI to load 読み込むMIDIのファイルパス
---@return dictionary       data of rhythm that Lua could easily interpret  抽出したデータをわかりやすく作り直したもの。
function M.midiToRhythm(pathMidi)
    local tbl = {"m2R is fine"}
    local dict = {}
    local string = M.midiOpenAsString(pathMidi)
    tbl[1] = string
    M.midiStringToBinArray(string)
    dict = M.midiDecode(string)
    printStrPairs(dict)
    debug_print("track")
    printArrayContents(dict.raw.track)
    debug_print("delta time")
    printArrayContents(dict.raw.deltaTime)
    debug_print("status")
    printArrayContents(dict.raw.status)
    debug_print("channel")
    printArrayContents(dict.raw.channel)
    debug_print("notes")
    printArrayContents(dict.raw.note)
    debug_print("velocity")
    printArrayContents(dict.raw.velocity)
    return tbl
end


return M