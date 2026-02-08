local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'

-- which method to use?  what is the pro vs con of either?
local sdl = require 'sdl'		-- assume sdl.setup was already called
--local sdl = require 'ffi.req' 'sdl2'	-- or get it from ffi.load ourselves

-- however these will still use `require 'sdl'` which will assume `setup'2'`
-- and if it is otherwise then you will get namespace/enum collisions
-- so you might as well just assume it is set up when require'ing sdl.
local sdlAssertZero = require 'sdl.assert'.zero
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

SDLApp.sdlMajorVersion = 2

-- fun fact
-- in SDL2, success is 0, and error codes are nonzero *plus* SDL_GetError().
-- in SDL3, success is 1, fail is 0, and SDL_GetError is the error reason.
function SDLApp.sdlAssert(...)
	return sdlAssertZero(...)
end

-- this seems like such a trivial thing but I have enough demo apps that do it often enough,
-- and it changed from SDL2 to SDL3
-- so here it is:
function SDLApp.sdlGetVersion()
	local version = ffi.new'SDL_version[1]'
	sdl.SDL_GetVersion(version)
	return version[0].major..'.'..version[0].minor..'.'..version[0].patch
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
	sdl.SDL_WINDOW_RESIZABLE,
	sdl.SDL_WINDOW_SHOWN
)

function SDLApp:run()
--DEBUG(@5):print'SDLApp:run begin'
--DEBUG(@5):print'SDL_Init()...'
	self.sdlAssert(sdl.SDL_Init(self.sdlInitFlags))

	xpcall(function()
		--[[ example A:
		local eventPtr = ffi.new('SDL_Event[1]')
		--]]
		-- [[ example B:
		local vector = require 'stl.vector'
		local eventBuffer = vector'SDL_Event'()
		eventBuffer:resize(256)
		--]]

		self:initWindow()
		self:resize()

--DEBUG(@5):print'starting event loop...'
		repeat
			--[[ example A:
			while sdl.SDL_PollEvent(eventPtr) > 0 do
			--]]
			-- [[ example B: is supposed to incur less overhead
--DEBUG(@5):print'SDL_PumpEvents()...'
			sdl.SDL_PumpEvents()
--DEBUG(@5):print('SDL_PeepEvents', eventBuffer.v, #eventBuffer, sdl.SDL_GETEVENT, sdl.SDL_FIRSTEVENT, sdl.SDL_LASTEVENT)
			local numEvents = sdl.SDL_PeepEvents(eventBuffer.v, #eventBuffer, sdl.SDL_GETEVENT, sdl.SDL_FIRSTEVENT, sdl.SDL_LASTEVENT)
--DEBUG(@5):print('numEvents =', numEvents)
			for i=0,numEvents-1 do
				local eventPtr = eventBuffer.v + i
			--]]
--DEBUG(@5):print('event.type', eventPtr[0].type)
				if eventPtr[0].type == sdl.SDL_QUIT then
--DEBUG(@5):print'calling self:requestExit()'
					self:requestExit()
--[[ screen
				elseif eventPtr[0].type == sdl.SDL_VIDEORESIZE then
					self.width = eventPtr[0].resize.w
					self.height = eventPtr[0].resize.h
					self.aspectRatio = self.width / self.height
					self:resize()
--]]
-- [[ window
				elseif eventPtr[0].type == sdl.SDL_WINDOWEVENT then
					if eventPtr[0].window.event == sdl.SDL_WINDOWEVENT_SIZE_CHANGED then
						self.width = eventPtr[0].window.data1
						self.height = eventPtr[0].window.data2
						self.aspectRatio = self.width / self.height
--DEBUG(@5):print'calling self:resize()'
						self:resize()
					end
--]]
				elseif eventPtr[0].type == sdl.SDL_KEYDOWN then
					if ffi.os == 'Windows' and eventPtr[0].key.keysym.sym == sdl.SDLK_F4 and bit.band(eventPtr[0].key.keysym.mod, sdl.KMOD_ALT) ~= 0 then
--DEBUG(@5):print'calling self:requestExit()'
						self:requestExit()
						break
					end
					if ffi.os == 'OSX' and eventPtr[0].key.keysym.sym == sdl.SDLK_q and bit.band(eventPtr[0].key.keysym.mod, sdl.KMOD_GUI) ~= 0 then
--DEBUG(@5):print'calling self:requestExit()'
						self:requestExit()
						break
					end
				end
				if self.event then
--DEBUG(@5):print'calling self:event()'
					self:event(eventPtr)
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
			sdl.SDL_WINDOWPOS_CENTERED,
			sdl.SDL_WINDOWPOS_CENTERED,
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
	[sdl.AUDIO_U8] = uint8_t,
	[sdl.AUDIO_S8] = int8_t,
	[sdl.AUDIO_S16] = int16_t,
	[sdl.AUDIO_U16] = uint16_t,
	[sdl.AUDIO_S32] = int32_t,
	[sdl.AUDIO_F32] = float,

	[sdl.AUDIO_S16SYS] = int16_t,
	[sdl.AUDIO_U16SYS] = uint16_t,
	[sdl.AUDIO_S32SYS] = int32_t,
	[sdl.AUDIO_F32SYS] = float,
}
SDLApp.sdlAudioFormatForCType = table.map(
	SDLApp.ctypeForSDLAudioFormat,
	function(v,k)
		return k,tostring(v)
	end)
	:setmetatable(nil)

return SDLApp
