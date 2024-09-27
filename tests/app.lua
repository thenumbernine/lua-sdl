#!/usr/bin/env luajit
local ffi = require 'ffi'
local sdl = require 'sdl'
local sdlAssertZero = require 'sdl.assert'.zero
local SDLApp = require 'sdl.app'
local App = SDLApp:subclass()
App.title = 'test'

function App:initWindow()
	App.super.initWindow(self)
	
	local version = ffi.new'SDL_version[1]'
	sdl.SDL_GetVersion(version)
	print'SDL_GetVersion:'
	print(version[0].major..'.'..version[0].minor..'.'..version[0].patch)


	for _,k in ipairs{
		--[[ segfaults on OSX:
		'SDL_GL_RED_SIZE',
		'SDL_GL_GREEN_SIZE',
		'SDL_GL_BLUE_SIZE',
		'SDL_GL_ALPHA_SIZE',
		'SDL_GL_BUFFER_SIZE',
		'SDL_GL_DOUBLEBUFFER',
		'SDL_GL_DEPTH_SIZE',
		'SDL_GL_STENCIL_SIZE',
		'SDL_GL_ACCUM_RED_SIZE',
		'SDL_GL_ACCUM_GREEN_SIZE',
		'SDL_GL_ACCUM_BLUE_SIZE',
		'SDL_GL_ACCUM_ALPHA_SIZE',
		'SDL_GL_STEREO',
		'SDL_GL_MULTISAMPLEBUFFERS',
		'SDL_GL_MULTISAMPLESAMPLES',
		--]]
		'SDL_GL_ACCELERATED_VISUAL',
		'SDL_GL_RETAINED_BACKING',
		'SDL_GL_CONTEXT_MAJOR_VERSION',
		'SDL_GL_CONTEXT_MINOR_VERSION',
		'SDL_GL_CONTEXT_EGL',
		'SDL_GL_CONTEXT_FLAGS',
		'SDL_GL_CONTEXT_PROFILE_MASK',
		'SDL_GL_SHARE_WITH_CURRENT_CONTEXT',
		'SDL_GL_FRAMEBUFFER_SRGB_CAPABLE',
		--[[ segfaults on OSX:
		'SDL_GL_CONTEXT_RELEASE_BEHAVIOR',
		--]]
		'SDL_GL_CONTEXT_RESET_NOTIFICATION',
		'SDL_GL_CONTEXT_NO_ERROR',
		'SDL_GL_FLOATBUFFERS',
	} do
		local v = ffi.new'int[1]'
		xpcall(function()
			sdlAssertZero(sdl.SDL_GL_GetAttribute(sdl[k], v))
			print(k..' = '..v[0])
		end, function(err)
			print(k..' = '..err)
		end)
	end
end

return App():run()
