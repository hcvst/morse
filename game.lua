local scene = storyboard.newScene()

local DIT = "."
local DAH = "-"
local INTRA_PAUSE = "_"

local ALPHABET = {
	A=".-",
	B="-...",
	C="-.-.",
	D="-..",
	E=".",
	F="..-.",
	G="--.",
	H="....",
	I="..",
	J=".---",
	K="-.-",
	L=".-..",
	M="--",
	N="-.",
	O="---",
	P=".--.",
	Q="--.-",
	R=".-.",
	S="...",
	T="-",
	U="..-",
	V="...-",
	W=".--",
	X="-..-",
	Y="-.--",
	Z="--.."
}

local PHONETIC = {
	A="ALPHA",
	B="BRAVO",
	C="CHARLIE",
	D="DELTA",
	E="ECHO",
	F="FOXTROT",
	G="GOLF",
	H="HOTEL",
	I="INDIA",
	J="JULIET",
	K="KILO",
	L="LIMA",
	M="MIKE",
	N="NOVEMBER",
	O="OSCAR",
	P="PAPA",
	Q="QUEBEC",
	R="ROMEO",
	S="SIERRA",
	T="TANGO",
	U="UNIFORM",
	V="VICTOR",
	W="WHISKEY",
	X="XRAY",
	Y="YANKEE",
	Z="ZULU"
}


-- https://en.wikipedia.org/wiki/Morse_code#Representation.2C_timing_and_speeds
local DURATION_IN_MILLISECONDS_SEND = 150
local DURATION_IN_MILLISECONDS_RECV = 120
local DURATION_DIT = 1 -- DIT's actual tone duration is this * DURATION_IN_MILLISECONDS 
local DURATION_DAH = 3
local DURATION_GAP_INTRA = 1 -- between the tones of a single letter
local DURATION_GAP_INTER = 3 -- between letters
local DURATION_GAP_WORDS = 7 -- between words

local W, H = display.contentWidth, display.contentHeight
local tone = audio.loadSound("750Hz.wav")
local CHANNEL = 1
local padel
local label
local isPressed
local pressedAtTime
local releasedAtTime
local isProcessed = true
local alphabetLookup = {}


function scene:createScene( event )
	padel = display.newRect( self.view, 0, 0, W * 0.9, H * 0.9 )
	padel:setFillColor(0, 0, 100)
	padel:setReferencePoint(display.CenterReferencePoint)
	padel.x = W / 2
	padel.y = H / 2
	label = display.newText(self.view, "Hi ABC", 0, 0, native.systemFontBold, 30)
	label:setReferencePoint(display.CenterReferencePoint)
	label.x = W / 2
	label.y = H / 2
	playSentence("Hello World")
	createAlphabetLookupTable()
end

function createAlphabetLookupTable()
	for k,v in pairs(ALPHABET) do
		local newKey = ""
		for c in v:gmatch('.') do
            newKey = newKey .. c .. INTRA_PAUSE
		end
		alphabetLookup[newKey] = k
	end
end

function scene:enterScene( event )
	padel:addEventListener("touch", onPadelTouch)
	Runtime:addEventListener("enterFrame", onEnterFrame)
end

function scene:exitScene( event )
	padel:removeEventListener("touch", onPadelTouch)
	Runtime:removeEventListener("enterFrame", onEnterFrame)
end

function scene:destroyScene( event )
end

function onPadelTouch(event)
	if event.phase == "began" then
		isProcessed = false
		isPressed = true
		pressedAtTime = event.time
		padel:setFillColor(200,100,0)
	    audio.play(tone, {channel=CHANNEL, loops=0})
    elseif event.phase == "ended" then
    	isPressed = false
    	releasedAtTime = event.time
		padel:setFillColor(0,0,100)
    	audio.stop(CHANNEL)
    end
end

function onEnterFrame(event)
	if not isPressed and not isProcessed then
		local duration = releasedAtTime - pressedAtTime
		pressDetected(duration)
		isProcessed = true
	elseif isProcessed and releasedAtTime then
		local duration = event.time - releasedAtTime
		pauseDetected(duration)
	end
end

local ditDahStack = {}
function pressDetected(duration)
	if duration < DURATION_IN_MILLISECONDS_SEND * DURATION_DIT then
		table.insert(ditDahStack, DIT)
	elseif duration < DURATION_IN_MILLISECONDS_SEND * DURATION_DAH then
		table.insert(ditDahStack, DAH)
    end
end

function pauseDetected(duration)
	if duration < DURATION_IN_MILLISECONDS_SEND * DURATION_GAP_INTRA then
		if ditDahStack[#ditDahStack] ~= INTRA_PAUSE then
    		table.insert(ditDahStack, INTRA_PAUSE)
    	end
	elseif #ditDahStack ~= 0 and duration < DURATION_IN_MILLISECONDS_SEND * DURATION_GAP_INTER then
		--print(table.concat(ditDahStack,""))
		label.text = interpretStack(ditDahStack)
    end
end

function interpretStack()
	local key = table.concat(ditDahStack, "")
	ditDahStack = {}
	return alphabetLookup[key]


end



function playSentence(sentence)
	local _, idx = sentence:find(" ")
	if idx and idx ~= 0 then
	    local head = sentence:sub(1, idx-1)
	    local tail = sentence:sub(idx+1)
	    playWord(head, 
	    	function()
	    		playGapWords(
	    			function()
	    				playSentence(tail)
	    			end
	    		)
	    	end
	    )
	else
		playWord(sentence)
	end
end


function playWord(word, onComplete)
	local function playRecursive(word)
		local head = word:sub(1,1)
		local tail = word:sub(2)

		local onPlaybackCompleteCallback = function()
			if tail ~= "" then
			    playGapInter(function() playRecursive(tail) end)
			else
				if onComplete then onComplete() end
		    end
		end
		playLetter(head, onPlaybackCompleteCallback)
	end
	playRecursive(word)
end

function playLetter(letter, onComplete)
	local function playRecursive(ditDahString)
		local head = ditDahString:sub(1,1)
		local tail = ditDahString:sub(2)

		local onPlaybackCompleteCallback = function()
			if tail ~= "" then
			    playGapIntra(function() playRecursive(tail) end)
			else
				if onComplete then onComplete() end
			end
		end
		if head == DIT then playDit(onPlaybackCompleteCallback) end
		if head == DAH then playDah(onPlaybackCompleteCallback) end
	end
	local ditDahString = ALPHABET[string.upper(letter)]
	playRecursive(ditDahString)
end

function playDit(onComplete)
	playToneForDuration(DURATION_DIT, onComplete)
end

function playDah(onComplete)
	playToneForDuration(DURATION_DAH, onComplete)
end

function playGapIntra(onComplete)
	playNoToneForDuration(DURATION_GAP_INTRA, onComplete)
end

function playGapInter(onComplete)
	playNoToneForDuration(DURATION_GAP_INTER, onComplete)
end

function playGapWords(onComplete)
	playNoToneForDuration(DURATION_GAP_WORDS, onComplete)
end

function playToneForDuration(duration, onComplete)
	audio.play(tone, {
		duration=duration * DURATION_IN_MILLISECONDS_RECV,
		onComplete=onComplete
	})
end

function playNoToneForDuration(duration, onComplete) -- Silence
	timer.performWithDelay(
		duration * DURATION_IN_MILLISECONDS_RECV, 
		onComplete)
end


scene:addEventListener( "createScene", scene )
scene:addEventListener( "enterScene", scene )
scene:addEventListener( "exitScene", scene )
scene:addEventListener( "destroyScene", scene )

return scene
