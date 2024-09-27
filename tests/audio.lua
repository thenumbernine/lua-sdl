#!/usr/bin/env luajit
local ffi = require 'ffi'
local sdl = require 'sdl'
local sdlAssertZero = require 'sdl.assert'.zero
local SDLApp = require 'sdl.app'
local App = SDLApp:subclass()

local function printSpecs(spec)
	print('', 'freq', spec[0].freq)
	print('', 'format', spec[0].format)
	print('', 'channels', spec[0].channels)
	print('', 'silence', spec[0].silence)
	print('', 'samples', spec[0].samples)
	print('', 'padding', spec[0].padding)
	print('', 'size', spec[0].size)
	print('', 'callback', spec[0].callback)
	print('', 'userdata', spec[0].userdata)
end

function App:initWindow()
	App.super.initWindow(self)

	-- init audio ...
	local numDrivers = sdl.SDL_GetNumAudioDrivers()
	print('num drivers:', numDrivers)
	print'drivers:'
	for i=0,numDrivers-1 do
		print(i, ffi.string(sdl.SDL_GetAudioDriver(i)))
	end

	sdlAssertZero(sdl.SDL_AudioInit'coreaudio')
	
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
		printSpecs(spec)
	end

	local desired = ffi.new'SDL_AudioSpec[1]'
	local sampleRate = 32000
	local bufferSizeInSeconds = 1
	self.channelCount = 2
	local singleChannelBufferSizeInSamples = bufferSizeInSeconds * sampleRate
	local allChannelsBufferSizeInSample = singleChannelBufferSizeInSamples * self.channelCount
	self.sampleType = 'int16_t'
	local allChannelsBufferSizeInBytes = allChannelsBufferSizeInSample * ffi.sizeof(self.sampleType)
	ffi.fill(desired, ffi.sizeof'SDL_AudioSpec')
	desired[0].freq = sampleRate
	desired[0].format = sdl.AUDIO_S16
	desired[0].channels = self.channelCount
	desired[0].samples = singleChannelBufferSizeInSamples -- in "sample frames" ... where stereo means two samples per "sample frame"
	desired[0].size = allChannelsBufferSizeInBytes		-- is calculated, but I wanted to make sure my calculations matched.
	print'desired specs:'
	printSpecs(desired)
	self.audioSpec = ffi.new'SDL_AudioSpec[1]'
	self.audioDeviceID = sdl.SDL_OpenAudioDevice(
		nil,	-- deviceName,	-- "Passing in a device name of NULL requests the most reasonable default"  from https://wiki.libsdl.org/SDL2/SDL_OpenAudioDevice
		isCapture, 
		desired,
		self.audioSpec,
		bit.bor(0,
			sdl.SDL_AUDIO_ALLOW_FREQUENCY_CHANGE,
			sdl.SDL_AUDIO_ALLOW_FORMAT_CHANGE,
			sdl.SDL_AUDIO_ALLOW_CHANNELS_CHANGE,
			sdl.SDL_AUDIO_ALLOW_SAMPLES_CHANGE,
		0)
	)
	print('obtained spec:')
	printSpecs(self.audioSpec)

	self.audioBufferLength = math.ceil(self.audioSpec[0].size / ffi.sizeof(self.sampleType))
	self.audioBuffer = ffi.new('int16_t[?]', self.audioBufferLength)
	local p = self.audioBuffer
	for i=0,singleChannelBufferSizeInSamples-1 do
		local t = i / sampleRate
		for j=0,self.channelCount-1 do
			p[0] = math.floor(32767 * math.sin(440 * t))
			p = p + 1
		end
	end
	assert(p == self.audioBuffer + self.audioBufferLength)
end

function App:update()
	local queued = sdl.SDL_GetQueuedAudioSize(self.audioDeviceID)
	if queued < self.audioSpec[0].size / (ffi.sizeof(self.sampleType) * self.channelCount) then
		print('queued:', queued)
		-- push audio here
		sdl.SDL_QueueAudio(
			self.audioDeviceID,
			self.audioBuffer,
			ffi.sizeof(self.audioBuffer)
		)
		sdl.SDL_PauseAudioDevice(self.audioDeviceID, 0)	-- pause 0 <=> play
	end
end

function App:exit()
	sdl.SDL_CloseAudioDevice(self.audioDeviceID)
	sdl.SDL_AudioQuit()

	App.super.exit(self)
end

return App():run()
