local M = {}

-- For Debug
local function printHex(num)
    debug_print(string.format("%x", num))
end

---@param path string   the path to MIDI to read.    
---@return string       MIDI as string of binary.   
function M.midiOpenAsString(pathMidi)
    local str = ""
    local file = assert(io.open(pathMidi, "rb"))
    if (not file) then
        str = "ERROR!"
        debug_print("MIDI load failed!")
    else
        str = file:read("*all")
        file:close()
        debug_print("Successfully closed!")
    end
    if (str:sub(1,4) ~= "MThd") then
        str = "NOT A VALID MIDI!"
        debug_print("MIDI is in a wrong format!")
    end
    return str
end

function M.midiStringToBinArray(string)
    local bnAry = {}
    for i=1, string:len() do
        bnAry[i] = string:byte(i)
        printHex(bnAry[i])
    end
    return bnAry
end

function M.midiDecode(string)
    local dict = {}
    local sizeNow = string:byte(7)*256 + string:byte(8)
    dict.midiFormat = string:byte(10)
    dict.numTrack = string:byte(12)
    dict.ppq = string:byte(13)*256 + string:byte(14)

    return dict
end

---@param pathMidi string   the file path for MIDI to load 読み込むMIDIのファイルパス
---@return dictionary       data of rhythm that Lua could easily interpret  抽出したデータをわかりやすく作り直したもの。
function M.midiToRhythm(pathMidi)
    local tbl = {"m2R is fine"}
    local string = M.midiOpenAsString(pathMidi)
    tbl[1] = string
    M.midiStringToBinArray(string)
    return tbl
end


return M