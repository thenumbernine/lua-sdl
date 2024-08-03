#!/usr/bin/env luajit
local ffi = require 'ffi'
local sdl = require 'sdl'
local SDLApp = require 'sdl.app'
local App = SDLApp:subclass()
App.title = 'test'

function App:initWindow()
	App.super.initWindow(self)
	
	local version = ffi.new'SDL_version[1]'
	sdl.SDL_GetVersion(version)
	print'SDL_GetVersion:'
	print(version[0].major..'.'..version[0].minor..'.'..version[0].patch)
end

return App():run()
