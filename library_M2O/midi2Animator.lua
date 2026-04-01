local M = {}

debug_print("Initiating MIDI2Otomad...")

M.CacheMidi         = {}
M.CacheNotePress    = {}
M.CacheLayer        = {path = {}}
M.CacheMisc         = {zoom = {}}

--Default values

M.scriptPath = "C:\\ProgramData\\aviutl2\\Script\\midi2otomad"
M.ppq = 960
M.bpm = 160
M.mesPlus = 0
M.framePlus = 0
M.metre = 4

M.curFrame  = 0
M.totFrame  = 60
M.curBeat   = 0
M.curMes    = 0
M.furBeat   = 0
M.furMes    = 0

---@param x number      [0,1] of animation, starting at 0 and ending at 1
---@param amp number    Amplitude used in some of easing
---@return number       [0,1] eased to appropraiate function. If index%3 is 2, it is a bounce: achieves 1 at middle and 0 at either end.
M.ease = {
    --linear
    [1] = function(x, amp) return x end,
    --triangle
    [2] = function(x, amp) return 1-math.abs(2*x-1) end,
    --quadratic in
    [3] = function(x, amp) return x^2 end,
    --quadratic out
    [4] = function(x, amp) return 1-(1-x)^2 end,
    --quadratic bounce
    [5] = function(x, amp) return 1-(1-2*x)^2 end,
    --cubic in
    [6] = function(x, amp) return x^3 end,
    --cubic out
    [7] = function(x, amp) return 1-(1-x)^3 end,
    --cubic bounce
    [8] = function(x, amp) return 1-math.abs((1-2*x)^3) end,
    --polynomial in
    [9] = function(x, amp) return x^amp end,
    --polynomial out
    [10] = function(x, amp) return 1-(1-x)^amp end,
    --polynomial bounce
    [11] = function(x, amp) return 1-math.abs((1-2*x))^amp end,
    --exponential in
    [12] = function(x, amp) return (2^(amp*(x-1))-2^-amp)/(1-2^-amp) end,
    --exponential out
    [13] = function(x, amp) return 1-((2^(-amp*x)-2^-amp)/(1-2^-amp)) end,
    --exponential bounce
    [14] = function(x, amp) return (1+2^(-amp)-2^(-amp*x)-2^(amp*(x-1)))/(1+2^(-amp)-2^(1-amp/2)) end,
    --sine in
    [15] = function(x, amp) return math.sin(x*math.pi/2) end,
    --sine out
    [16] = function(x, amp) return 1-math.cos(x*math.pi/2) end,
    --sine bounce
    [17] = function(x, amp) return math.sin(x*math.pi) end
}

---@param time timeSecond
---@return timeBeat
function M.toBeat(time)
    return time*M.bpm/60
end

-- inverse
---@param time timeBeat
---@return timeSecond
function M.unBeat(time)
    return time*60/M.bpm
end

---@param num number    number
---@return number       sign of the number
function M.sign(num)
    return (num>0) and 1 or ((num<0) and -1 or 0)
end

function M.findLatestNote(currentTime, noteEvents, lastIndexRead)
    if(not lastIndexRead) then
        lastIndexRead = 1
    elseif(noteEvents.time[lastIndexRead] > currentTime) then
        --debug_print("BACK TRACK")
        lastIndexRead = 1
    end
    local iMin, iSup, pos, val= lastIndexRead, #noteEvents.time, 0, 0
    
    while (iMin <= iSup) do
        pos = math.floor((iMin + iSup)/2)
        val, nextVal = noteEvents.time[pos], (noteEvents.time[pos+1] or noteEvents.time[pos]*2)
        if((val <= currentTime) and (currentTime < nextVal)) then
            return pos
        elseif (val < currentTime) then
            iMin = pos + 1
        else
            iSup = pos - 1
        end
    end

    return pos
end

function M.playNote(currentTime, noteEvents, index)
    local sustain = currentTime - noteEvents.time[index]
    local sustNorm = sustain/noteEvents.length[index]
    local isPressed = sustNorm <= 1
    return sustain, sustNorm, isPressed
end

function M.playLatestNote(currentTime, noteEvents, lastIndexRead)
    local index = M.findLatestNote(currentTime, noteEvents, lastIndexRead)
    local sustain, sustNorm, isPressed = M.playNote(currentTime, noteEvents, index)
    return index, sustain, sustNorm, isPressed
end

---@param pathMidi string   Decode MIDI file at the path, stores it in a cache only once. Will not read if cache already exists.
---@param resetThis int     Deletes the cache to re-read the MIDI file.
function M.saveCacheMidi(pathMidi, resetThis)
    if(resetThis == 1) then
        Akto.MidiToAnimator.CacheMidi[pathMidi] = nil
    end

    if(not (Akto.MidiToAnimator.CacheMidi[pathMidi])) then
        Akto.MidiToAnimator.CacheMidi[pathMidi] = Akto.MidiToAnalyzer.midiToRhythm(pathMidi)
        debug_print("Scanned MIDI at: "..pathMidi)
    end
end 

function M.saveCacheLatestNote(currentTime, noteEvents, lastIndexRead, path)
    if((not path) or path == "") then
        path = obj.layer
    else
        M.CacheLayer.path[obj.layer] = path
    end
    if(not (M.CacheNotePress[path])) then
        M.CacheNotePress[path] = { index = 1, sustain = 0, sustNorm = 0, isPressed = false}
    end
    local a,b,c,d = M.playLatestNote(currentTime, noteEvents, lastIndexRead)
    M.CacheNotePress[path].index = a
    M.CacheNotePress[path].sustain = b
    M.CacheNotePress[path].sustNorm = c
    M.CacheNotePress[path].isPressed = d
end

function M.loadCacheLatestNote(path)
    if((not path) or path == "") then
        path = M.CacheLayer.path[obj.layer]
    end
    local N = M.CacheNotePress[path]
    if(not N) then
        obj.load("text", "selected MIDI is not loaded!\n選択したMIDIが読み込まれていません！")
        N = {index = 0, sustain = 0, sustNorm = 0, isPressed = false}
    end
    return N.index, N.sustain, N.sustNorm, N.isPressed
end

return M