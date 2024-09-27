#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local asserteq = require 'ext.assert'.eq
local assertindex = require 'ext.assert'.index
local sdl = require 'sdl'
local sdlAssertZero = require 'sdl.assert'.zero
local SDLApp = require 'sdl.app'
local App = SDLApp:subclass()

local ctypeForSDLAudioFormat =  {
	-- TODO 'LSB' vs 'MSB' ...
	-- TODO how to determine unique types for each of these ...
	[sdl.AUDIO_U8] = 'uint8_t',
	[sdl.AUDIO_S8] = 'int8_t',
	[sdl.AUDIO_S16] = 'int16_t',
	[sdl.AUDIO_U16] = 'uint16_t',
	[sdl.AUDIO_S32] = 'int32_t',
	[sdl.AUDIO_F32] = 'float',

	[sdl.AUDIO_S16SYS] = 'int16_t',
	[sdl.AUDIO_U16SYS] = 'uint16_t',
	[sdl.AUDIO_S32SYS] = 'int32_t',
	[sdl.AUDIO_F32SYS] = 'float',
}
local sdlAudioFormatForCType = table.map(ctypeForSDLAudioFormat, function(v,k) return k,v end):setmetatable(nil)

local function printSpecs(spec)
	print('', 'freq', spec.freq)
	print('', 'format', spec.format, ctypeForSDLAudioFormat[spec.format])
	print('', 'channels', spec.channels)
	print('', 'silence', spec.silence)
	print('', 'samples', spec.samples)
	print('', 'padding', spec.padding)
	print('', 'size', spec.size)
	print('', 'callback', spec.callback)
	print('', 'userdata', spec.userdata)
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
		printSpecs(spec[0])
	end

	local desired = ffi.new'SDL_AudioSpec[1]'
	self.sampleFrameRate = 32000
	local bufferSizeInSeconds = 1
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
	bufferSizeInSeconds = self.bufferSizeInSampleFrames / self.sampleFrameRate
	self.audioBufferLength = math.ceil(self.bufferSizeInBytes / ffi.sizeof(self.sampleType))
	self.audioBuffer = ffi.new(self.sampleType..'[?]', self.audioBufferLength)
	self:updateAudio()
	print'starting audio...'
	sdl.SDL_PauseAudioDevice(self.audioDeviceID, 0)	-- pause 0 <=> play
end

function App:fillAudioBuffer()
	local p = self.audioBuffer
	for i=0,self.bufferSizeInSampleFrames-1 do
		local t = i / self.sampleFrameRate
		local ampl = 32767 * math.sin(220 * t * (2 * math.pi))
		for j=0,self.channelCount-1 do
			p[0] = ampl
			p = p + 1
		end
	end
	asserteq(
		ffi.cast('char*', p),
		ffi.cast('char*', self.audioBuffer) + self.bufferSizeInBytes
	)
end

function App:updateAudio()
	local queuedInBytes = sdl.SDL_GetQueuedAudioSize(self.audioDeviceID)
	if queuedInBytes < .1 * self.bufferSizeInBytes then
		print('refilling queue')
		-- push audio here
		self:fillAudioBuffer()
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
