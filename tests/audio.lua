#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local getTime = require 'ext.timer'.getTime
local assert = require 'ext.assert'
local sdl = require 'sdl'
local SDLApp = require 'sdl.app'

local char_p = ffi.typeof'char*'
local int16_t = ffi.typeof'int16_t'
local int_1 = ffi.typeof'int[1]'
local SDL_AudioSpec = ffi.typeof'SDL_AudioSpec'
local SDL_AudioSpec_1 = ffi.typeof'SDL_AudioSpec[1]'

local App = SDLApp:subclass()
App.sdlInitFlags = bit.bor(App.sdlInitFlags, sdl.SDL_INIT_AUDIO)

local fn = ...

local ctypeForSDLAudioFormat = SDLApp.ctypeForSDLAudioFormat
local sdlAudioFormatForCType = SDLApp.sdlAudioFormatForCType

local function printSpecs(spec)
	local ctype = ctypeForSDLAudioFormat[spec.format]
	local sizeofctype = ctype and ffi.sizeof(ctype) or 0
	print('\tfreq = '..tostring(spec.freq))
	print('\tformat = '..tostring(spec.format)..'.. ctype='..tostring(ctype))
	print('\t sizeof ctype = '..tostring(sizeofctype))
	print('\tchannels = '..tostring(spec.channels))
end

local function fillBuffer(userdata, stream, additional, len)
	print'fillBuffer'
end
local fillBufferCallback = ffi.cast('void __stdcall (*)(void*, SDL_AudioStream*, int, int)', fillBuffer)

function App:initWindow()
	App.super.initWindow(self)

	-- init audio ...
	local numDrivers = sdl.SDL_GetNumAudioDrivers()
	print('num drivers:', numDrivers)
	print'drivers:'
	for i=0,numDrivers-1 do
		print(i, ffi.string(sdl.SDL_GetAudioDriver(i)))
	end

--[[ crashing
print'here'
	local numDevices = int_1()
	local devices = sdl.SDL_GetAudioPlaybackDevices(numDevices)
	print('num devices:', numDevices[0])
	print'devices:'
	local deviceName
	for i=0,numDevices[0]-1 do
		local ithName = ffi.string(sdl.SDL_GetAudioDeviceName(i))
		deviceName = deviceName or ithName
		print(i, ithName)
		local spec = SDL_AudioSpec_1()
		local sampleFrames = int_1()
		self.sdlAssert(sdl.SDL_GetAudioDeviceSpec(i, spec, sampleFrames))
		--printSpecs(spec[0])	-- this just has channels filled out
	end
print'here'
--]]

	local desired = SDL_AudioSpec_1()
	if fn then
		self.wav = require 'audio.io.wav'():load(fn)
		desired[0].freq = self.wav.freq
		desired[0].format = sdlAudioFormatForCType[tostring(self.wav.ctype)]
		desired[0].channels = self.wav.channels
		desired[0].samples = self.wav.size / (self.wav.channels * ffi.sizeof(self.wav.ctype))
		desired[0].size = self.wav.size
	else
		self.sampleFrameRate = 32000
		local bufferSizeInSeconds = .075		-- 9600 bytes	= doesn't divide evenly, so make sure to regenerate waveforms based on correct 't' for the new buffers
		--local bufferSizeInSeconds = .05		-- 6400 bytes = 3200 sample-frames = 1600 samples
		--local bufferSizeInSeconds = .025	-- 3200 bytes isn't enough to stream? docs say to use 1k-8k ... but 3k isn't working ...
		self.channelCount = 2
		self.bufferSizeInSampleFrames = bufferSizeInSeconds * self.sampleFrameRate
		local bufferSizeInSamples = self.bufferSizeInSampleFrames * self.channelCount
		self.sampleType = int16_t
		self.bufferSizeInBytes = bufferSizeInSamples * ffi.sizeof(self.sampleType)
		ffi.fill(desired, ffi.sizeof(SDL_AudioSpec))
		desired[0].freq = self.sampleFrameRate
		desired[0].format = sdlAudioFormatForCType[tostring(self.sampleType)]
		desired[0].channels = self.channelCount
		-- removed in sdl3 ... uhhh ... how big is the buffer?
		--desired[0].samples = self.bufferSizeInSampleFrames -- in "sample frames" ... where stereo means two samples per "sample frame"
		--desired[0].size = self.bufferSizeInBytes		-- is calculated, but I wanted to make sure my calculations matched.
	end

	self.audioStream = sdl.SDL_OpenAudioDeviceStream(sdl.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, desired, nil, nil)
	self.audioSpec = desired -- uhh what happened to desired vs actual?
	assert.ne(self.audioStream, ffi.null, "SDL_OpenAudioDeviceStream failed")

	-- recalculate based on what we're given
	self.sampleFrameRate = self.audioSpec[0].freq
	self.channelCount = self.audioSpec[0].channels
	self.sampleType = assert.index(ctypeForSDLAudioFormat, tonumber(self.audioSpec[0].format))
	bufferSizeInSamples = self.bufferSizeInBytes / ffi.sizeof(self.sampleType)
	self.bufferSizeInSampleFrames = bufferSizeInSamples / self.channelCount
	self.bufferSizeInSeconds = self.bufferSizeInSampleFrames / self.sampleFrameRate
	self.audioBufferLength = math.ceil(self.bufferSizeInBytes / ffi.sizeof(self.sampleType))
	self.sampleIndex = 0
	if not fn then
		local sampleTypeArr = ffi.typeof('$[?]', self.sampleType)
		self.audioBuffer = sampleTypeArr(self.audioBufferLength)
		self:fillAudioBuffer()
	else
		self.audioBuffer = self.wav.data
	end

	self.audioDeviceID = sdl.SDL_GetAudioStreamDevice(self.audioStream)

	self.lastPlayTime = getTime()
	self:updateAudio()
	print'starting audio...'
	sdl.SDL_ResumeAudioDevice(self.audioDeviceID)
end

function App:fillAudioBuffer()
	local p = self.audioBuffer
	for i=0,self.bufferSizeInSampleFrames-1 do
		local t = self.sampleIndex / self.sampleFrameRate
		local ampl = 32767 * math.sin(220 * t * (2 * math.pi))
		for j=0,self.channelCount-1 do
			p[0] = ampl
			p = p + 1
		end
		self.sampleIndex = self.sampleIndex + 1
	end
	assert.eq(
		ffi.cast(char_p, p),
		ffi.cast(char_p, self.audioBuffer) + self.bufferSizeInBytes
	)
end

function App:updateAudio()
	--[[ refill based on queued bytes ... this function seems to go 0 to 100% and nothing between ...
	-- I get a skip at first when playing back, but then it smooths out
	local queuedInBytes = sdl.SDL_GetQueuedAudioSize(self.audioDeviceID)
	if queuedInBytes < .1 * self.bufferSizeInBytes then
	--]]
	-- [[ refill based on tracking time ourselves and hoping it's not out of sync with SDL audio's time such that long-term we get an overflow/underflow
	-- seems to work perfectly.
	-- don't forget to update the queue before the audio is empty
	local thisTime = getTime()
	if thisTime - self.lastPlayTime > self.bufferSizeInSeconds then
		if math.floor(thisTime) ~= math.floor(self.lastPlayTime) then
			-- ok I really dont' trust the GetQueueAudioSize as an indicator at all now, because when I track time myself, I hear no underflow, and the queue is always reporting zero.
			-- so I think I shouldn't use the queue to detect when to refill the queue, instead I need to track playback time myself ...
--			print('queued', sdl.SDL_GetQueuedAudioSize(self.audioDeviceID))	-- uhhh how long is it?
		end
		self.lastPlayTime = thisTime
	--]]
--print('refilling queue')
		if not self.wav then
			self:fillAudioBuffer()
		end
		-- push audio here
		self.sdlAssert(sdl.SDL_PutAudioStreamData(
			self.audioStream,
			self.audioBuffer,
			self.bufferSizeInBytes
		))
		-- do we have to keep calling this?  what if we get an underflow - will sdl auto-pause?
		--sdl.SDL_PauseAudioDevice(self.audioDeviceID, 0)	-- pause 0 <=> play
	end
end

function App:update()
	self:updateAudio()
end

function App:exit()
	sdl.SDL_CloseAudioDevice(self.audioDeviceID)
	--[[ if sdl2
	sdl.SDL_AudioQuit()
	--]]
	-- [[ if sdl3
	sdl.SDL_QuitSubSystem(sdl.SDL_INIT_AUDIO)
	--]]

	App.super.exit(self)
end

return App():run()
