local ffi = require 'ffi'
local sdl = require 'ffi.req' 'sdl'
local class = require 'ext.class'

local sdlAssertZero = require 'sdlapp.assert'.zero
local sdlAssertNonNull = require 'sdlapp.assert'.nonnull

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

-- functions or variables? which to use ...
SDLApp.sdlInitFlags = sdl.SDL_INIT_VIDEO

SDLApp.sdlCreateWindowFlags = bit.bor(
	sdl.SDL_WINDOW_RESIZABLE,
	sdl.SDL_WINDOW_SHOWN
)

function SDLApp:run()
	sdlAssertZero(sdl.SDL_Init(self.sdlInitFlags))

	xpcall(function()
		local eventPtr = ffi.new('SDL_Event[1]')

		self:initWindow()
		sdl.SDL_SetWindowSize(self.window, self.width, self.height)

		repeat
			while sdl.SDL_PollEvent(eventPtr) > 0 do
				if eventPtr[0].type == sdl.SDL_QUIT then
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
						self:resize()
					end
--]]
				elseif eventPtr[0].type == sdl.SDL_KEYDOWN then
					if ffi.os == 'Windows' and eventPtr[0].key.keysym.sym == sdl.SDLK_F4 and bit.band(eventPtr[0].key.keysym.mod, sdl.KMOD_ALT) ~= 0 then
						self:requestExit()
						break
					end
					if ffi.os == 'OSX' and eventPtr[0].key.keysym.sym == sdl.SDLK_q and bit.band(eventPtr[0].key.keysym.mod, sdl.KMOD_GUI) ~= 0 then
						self:requestExit()
						break
					end
				end
				if self.onEvent then
					self:onEvent(eventPtr)
				end
			end

			if self.onUpdate then self:onUpdate() end
		until self.done
	end, function(err)
		print(err)
		print(debug.traceback())
	end)

	if self.onExit then self:onExit() end

	sdl.SDL_DestroyWindow(self.window);
	sdl.SDL_Quit()
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

return SDLApp
