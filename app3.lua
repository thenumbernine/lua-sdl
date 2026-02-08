local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local sdl = require 'sdl'

local sdlAssertNonZero = require 'sdl.assert'.nonzero
local sdlAssertNonNull = require 'sdl.assert'.nonnull

--[[
parameters to override prior to init:
	width, height = initial window size
	title = initial window title
	sdlInitFlags = flags for SDL_Init
	sdlCreateWindowFlags = flags for SDL_CreateWindow
	initWindow() = called after SDL window init
	update() = called once per frame
	resize() = called upon resize, self.width and self.height hold the current size
	event(eventPtr) = called per SDL event
	exit() = called upon shutdown
--]]
local SDLApp = class()

SDLApp.sdlMajorVersion = 3

-- fun fact
-- in SDL2, success is 0, and error codes are nonzero *plus* SDL_GetError().
-- in SDL3, success is 1, fail is 0, and SDL_GetError is the error reason.
function SDLApp.sdlAssert(...)
	return sdlAssertNonZero(...)
end

-- this seems like such a trivial thing but I have enough demo apps that do it often enough,
-- and it changed from SDL2 to SDL3
-- so here it is:
function SDLApp.sdlGetVersion()
	-- I'd put these in ffi/sdl3.lua but I don't want any lua metatable wrappers of ffi.load over it.
	-- #define SDL_VERSIONNUM_MAJOR(version) ((version) / 1000000)
	-- #define SDL_VERSIONNUM_MINOR(version) (((version) / 1000) % 1000)
	-- #define SDL_VERSIONNUM_MICRO(version) ((version) % 1000)
	local version = sdl.SDL_GetVersion()
	local micro = version % 1000
	local minor = math.floor(version / 1000) % 1000
	local major = math.floor(version / 1000000)
	return major..'.'..minor..'.'..micro
end

function SDLApp:init()
	self.done = false
end

function SDLApp:requestExit()
	self.done = true
end

function SDLApp:size()
	return self.width, self.height
end

SDLApp.title = "SDL App"
SDLApp.width = 640
SDLApp.height = 480

SDLApp.sdlInitFlags = sdl.SDL_INIT_VIDEO

SDLApp.sdlCreateWindowFlags = bit.bor(
	sdl.SDL_WINDOW_RESIZABLE
)

--[[ example A:
local eventPtr = ffi.new('SDL_Event[1]')
--]]
-- [[ example B
local vector = require 'stl.vector'
local eventBuffer = vector'SDL_Event'()
eventBuffer:resize(256)
---]]

function SDLApp:run()
--DEBUG(@5):print'SDLApp:run begin'
--DEBUG(@5):print'SDL_Init()...'
	self.sdlAssert(sdl.SDL_Init(self.sdlInitFlags))

	xpcall(function()

		self:initWindow()
		self:resize()

--DEBUG(@5):print'starting event loop...'
		repeat
			--[[ example A:
			while sdl.SDL_PollEvent(eventPtr) do
			--]]
			-- [[ example B: is supposed to incur less overhead
--DEBUG(@5):print'SDL_PumpEvents()...'
			sdl.SDL_PumpEvents()
--DEBUG(@5):print('SDL_PeepEvents', eventBuffer.v, #eventBuffer, sdl.SDL_GETEVENT, sdl.SDL_EVENT_FIRST, sdl.SDL_EVENT_LAST)
			local numEvents = sdl.SDL_PeepEvents(eventBuffer.v, #eventBuffer, sdl.SDL_GETEVENT, sdl.SDL_EVENT_FIRST, sdl.SDL_EVENT_LAST)
--DEBUG(@5):print('numEvents =', numEvents)
			for i=0,numEvents-1 do
				local event = eventBuffer.v + i
			--]]
---DEBUG(@5):print('event.type', eventPtr[0].type)
				if event.type == sdl.SDL_EVENT_QUIT then
---DEBUG(@5):print'calling self:requestExit()'
					self:requestExit()
--[[ screen
				elseif event.type == sdl.SDL_VIDEORESIZE then
					self.width = event.resize.w
					self.height = event.resize.h
					self.aspectRatio = self.width / self.height
					self:resize()
--]]
-- [[ window
				elseif event.type == sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED then
					self.width = event.window.data1
					self.height = event.window.data2
					self.aspectRatio = self.width / self.height
--DEBUG(@5):print'calling self:resize()'
					self:resize()
--]]
				elseif event.type == sdl.SDL_EVENT_KEY_DOWN then
					if ffi.os == 'Windows'
					and event.key.key == sdl.SDLK_F4
					and bit.band(event.key.mod, sdl.SDL_KMOD_ALT) ~= 0
					then
--DEBUG(@5):print'calling self:requestExit()'
						self:requestExit()
						break
					end
					if ffi.os == 'OSX'
					and event.key.key == sdl.SDLK_Q
					and bit.band(event.key.mod, sdl.SDL_KMOD_GUI) ~= 0
					then
--DEBUG(@5):print'calling self:requestExit()'
						self:requestExit()
						break
					end
				end
				if self.event then
--DEBUG(@5):print'calling self:event()'
					self:event(event)
				end
			end

--DEBUG(@5):print'calling self:update()'
			self:update()

			-- separate update call here to ensure it runs last
			-- yeah this is just for GLApp or anyone else who needs to call some form of swap/flush
--DEBUG(@5):print'calling self:postUpdate()'
			self:postUpdate()

		until self.done
	end, function(err)
		print(err)
		print(debug.traceback())
	end)

--DEBUG(@5):print'done, calling self:exit()'
	self:exit()
--DEBUG(@5):print'SDLApp:run done'
end

function SDLApp:initWindow()
--[[ screen
		local screenFlags = bit.bor(sdl.SDL_DOUBLEBUF, sdl.SDL_RESIZABLE)
		local screen = sdl.SDL_SetVideoMode(self.width, self.height, 0, screenFlags)
--]]
-- [[ window
		self.window = sdlAssertNonNull(sdl.SDL_CreateWindow(
			self.title,
			self.width,
			self.height,
			self.sdlCreateWindowFlags))
--]]
end

function SDLApp:resize()
end

function SDLApp:event(e)
end

function SDLApp:update()
end

function SDLApp:postUpdate()
end

function SDLApp:exit()
	-- TODO use gcwrapper?  or would that ensure order of dtor?
	sdl.SDL_DestroyWindow(self.window);
	sdl.SDL_Quit()
end

local uint8_t = ffi.typeof'uint8_t'
local int8_t = ffi.typeof'int8_t'
local int16_t = ffi.typeof'int16_t'
local int32_t = ffi.typeof'int32_t'
local float = ffi.typeof'float'

-- should I make a separate sdl namespace that separates per-version that isn't SDLApp?
SDLApp.ctypeForSDLAudioFormat =  {
	-- TODO 'LSB' vs 'MSB' ...
	-- TODO how to determine unique types for each of these ...
	[tonumber(sdl.SDL_AUDIO_U8)] = uint8_t,
	[tonumber(sdl.SDL_AUDIO_S8)] = int8_t,
	[tonumber(sdl.SDL_AUDIO_S16LE)] = int16_t,
	[tonumber(sdl.SDL_AUDIO_S16BE)] = int16_t,
	[tonumber(sdl.SDL_AUDIO_S32LE)] = int32_t,
	[tonumber(sdl.SDL_AUDIO_S32BE)] = int32_t,
	[tonumber(sdl.SDL_AUDIO_F32LE)] = float,
	[tonumber(sdl.SDL_AUDIO_F32BE)] = float,

	[tonumber(sdl.SDL_AUDIO_S16)] = int16_t,
	[tonumber(sdl.SDL_AUDIO_S32)] = int32_t,
	[tonumber(sdl.SDL_AUDIO_F32)] = float,
}
SDLApp.sdlAudioFormatForCType = table.map(
	SDLApp.ctypeForSDLAudioFormat,
	function(v,k)
		return k, tostring(v)
	end)
	:setmetatable(nil)

return SDLApp
