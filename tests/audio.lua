#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local getTime = require 'ext.timer'.getTime
local asserteq = require 'ext.assert'.eq
local assertindex = require 'ext.assert'.index
local sdl = require 'sdl'
local sdlAssertZero = require 'sdl.assert'.zero
local SDLApp = require 'sdl.app'

local App = SDLApp:subclass()
App.sdlInitFlags = bit.bor(App.sdlInitFlags, sdl.SDL_INIT_AUDIO)

local fn = ...

local ctypeForSDLAudioFormat = require 'sdl.audio'.ctypeForSDLAudioFormat
local sdlAudioFormatForCType = require 'sdl.audio'.sdlAudioFormatForCType

local function printSpecs(spec)
	local ctype = ctypeForSDLAudioFormat[spec.format]
	local sizeofctype = ctype and ffi.sizeof(ctype) or 0
	print('\tfreq = '..tostring(spec.freq))
	print('\tformat = '..tostring(spec.format)..'.. ctype='..tostring(ctype))
	print('\t sizeof ctype = '..tostring(sizeofctype))
	print('\tchannels = '..tostring(spec.channels))
	print('\tsilence = '..tostring(spec.silence))
	print('\tsamples = '..tostring(spec.samples))
	print('\tpadding = '..tostring(spec.padding))
	print('\tsize = '..tostring(spec.size))
	print('\t size in seconds = '..tostring(
		tonumber(spec.size) / tonumber(spec.freq * spec.channels * sizeofctype)
	))
	print('\tcallback = '..tostring(spec.callback))
	print('\tuserdata = '..tostring(spec.userdata))
end

local function fillBuffer(userdata, stream, len)
	print'fillBuffer'
end
local fillBufferCallback = ffi.cast('SDL_AudioCallback', fillBuffer)

function App:initWindow()
	App.super.initWindow(self)

	-- init audio ...
	local numDrivers = sdl.SDL_GetNumAudioDrivers()
	print('num drivers:', numDrivers)
	print'drivers:'
	for i=0,numDrivers-1 do
		print(i, ffi.string(sdl.SDL_GetAudioDriver(i)))
	end

	local isCapture = 0
	local numDevices = sdl.SDL_GetNumAudioDevices(isCapture)
	print('num devices:', numDevices)
	print'devices:'
	local deviceName
	for i=0,numDevices-1 do
		local ithName = ffi.string(sdl.SDL_GetAudioDeviceName(i, isCapture))
		deviceName = deviceName or ithName
		print(i, ithName)
		local spec = ffi.new'SDL_AudioSpec[1]'
		sdlAssertZero(sdl.SDL_GetAudioDeviceSpec(i, isCapture, spec))
		--printSpecs(spec[0])	-- this just has channels filled out
	end

	local desired = ffi.new'SDL_AudioSpec[1]'
	if fn then
		self.wav = require 'audio.io.wav'():load(fn)
		desired[0].freq = self.wav.freq
		desired[0].format = sdlAudioFormatForCType[self.wav.ctype]
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
		self.sampleType = 'int16_t'
		self.bufferSizeInBytes = bufferSizeInSamples * ffi.sizeof(self.sampleType)
		ffi.fill(desired, ffi.sizeof'SDL_AudioSpec')
		desired[0].freq = self.sampleFrameRate
		desired[0].format = sdlAudioFormatForCType[self.sampleType]
		desired[0].channels = self.channelCount
		desired[0].samples = self.bufferSizeInSampleFrames -- in "sample frames" ... where stereo means two samples per "sample frame"
		desired[0].size = self.bufferSizeInBytes		-- is calculated, but I wanted to make sure my calculations matched.
	end
	-- "SDL_GetError(): Audio device has a callback, queueing not allowed"
	--desired[0].callback = fillBufferCallback
	print'desired specs:'
	printSpecs(desired[0])
	self.audioSpec = ffi.new'SDL_AudioSpec[1]'
	self.audioDeviceID = sdl.SDL_OpenAudioDevice(
		nil,	-- deviceName,	-- "Passing in a device name of NULL requests the most reasonable default"  from https://wiki.libsdl.org/SDL2/SDL_OpenAudioDevice
		isCapture,
		desired,
		self.audioSpec,
		bit.bor(0,
		-- [[
			sdl.SDL_AUDIO_ALLOW_FREQUENCY_CHANGE,
			sdl.SDL_AUDIO_ALLOW_FORMAT_CHANGE,
			sdl.SDL_AUDIO_ALLOW_CHANNELS_CHANGE,
			sdl.SDL_AUDIO_ALLOW_SAMPLES_CHANGE,
			0
		--]]
		)
	)
	print('obtained spec:')
	printSpecs(self.audioSpec[0])

	-- recalculate based on what we're given
	self.bufferSizeInBytes = self.audioSpec[0].size
	self.sampleFrameRate = self.audioSpec[0].freq
	self.channelCount = self.audioSpec[0].channels
	self.sampleType = assertindex(ctypeForSDLAudioFormat, self.audioSpec[0].format)
	bufferSizeInSamples = self.bufferSizeInBytes / ffi.sizeof(self.sampleType)
	self.bufferSizeInSampleFrames = bufferSizeInSamples / self.channelCount
	self.bufferSizeInSeconds = self.bufferSizeInSampleFrames / self.sampleFrameRate
	self.audioBufferLength = math.ceil(self.bufferSizeInBytes / ffi.sizeof(self.sampleType))
	self.sampleIndex = 0
	if not fn then
		self.audioBuffer = ffi.new(self.sampleType..'[?]', self.audioBufferLength)
		self:fillAudioBuffer()
	else
		self.audioBuffer = self.wav.data
	end
	self.lastPlayTime = getTime()
	self:updateAudio()
	print'starting audio...'
	sdl.SDL_PauseAudioDevice(self.audioDeviceID, 0)	-- pause 0 <=> play
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
	asserteq(
		ffi.cast('char*', p),
		ffi.cast('char*', self.audioBuffer) + self.bufferSizeInBytes
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
			print('queued', sdl.SDL_GetQueuedAudioSize(self.audioDeviceID))
		end
		self.lastPlayTime = thisTime
	--]]
--print('refilling queue')
		if not self.wav then
			self:fillAudioBuffer()
		end
		-- push audio here
		sdlAssertZero(sdl.SDL_QueueAudio(
			self.audioDeviceID,
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
	sdl.SDL_AudioQuit()

	App.super.exit(self)
end

return App():run()
