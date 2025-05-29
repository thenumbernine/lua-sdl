#!/usr/bin/env luajit
local ffi = require 'ffi'
local sdl, SDLApp = require 'sdl.setup'(...)
local App = SDLApp:subclass()
App.title = 'test'

-- [[ SDL3 bug? If I don't create a GL window then it doesn't make a window at all....
local gl = require 'gl'
App.sdlCreateWindowFlags = bit.bor(App.sdlCreateWindowFlags, sdl.SDL_WINDOW_OPENGL)
function App:postUpdate()
	sdl.SDL_GL_SwapWindow(self.window)
end
--]]

function App:initWindow()
	print('SDL_GetVersion:', self.sdlGetVersion())
	App.super.initWindow(self)
-- [[ SDL3 bug? If I don't create a GL window then it doesn't make a window at all....
	local sdlAssertNonNull = require 'sdl.assert'.nonnull
	self.sdlCtx = sdlAssertNonNull(sdl.SDL_GL_CreateContext(self.window))
	sdl.SDL_GL_SetSwapInterval(0)
--]]

	for _,k in ipairs{
		--[=[ SDL2 GL attributes:
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
		--]=]
		-- [=[ list from https://wiki.libsdl.org/SDL3/SDL_GLAttr
		'SDL_GL_RED_SIZE',                    --the minimum number of bits for the red channel of the color buffer; defaults to 8.
		'SDL_GL_GREEN_SIZE',                  --the minimum number of bits for the green channel of the color buffer; defaults to 8.
		'SDL_GL_BLUE_SIZE',                   --the minimum number of bits for the blue channel of the color buffer; defaults to 8.
		'SDL_GL_ALPHA_SIZE',                  --the minimum number of bits for the alpha channel of the color buffer; defaults to 8.
		'SDL_GL_BUFFER_SIZE',                 --the minimum number of bits for frame buffer size; defaults to 0.
		'SDL_GL_DOUBLEBUFFER',                --whether the output is single or double buffered; defaults to double buffering on.
		'SDL_GL_DEPTH_SIZE',                  --the minimum number of bits in the depth buffer; defaults to 16.
		'SDL_GL_STENCIL_SIZE',                --the minimum number of bits in the stencil buffer; defaults to 0.
		'SDL_GL_ACCUM_RED_SIZE',              --the minimum number of bits for the red channel of the accumulation buffer; defaults to 0.
		'SDL_GL_ACCUM_GREEN_SIZE',            --the minimum number of bits for the green channel of the accumulation buffer; defaults to 0.
		'SDL_GL_ACCUM_BLUE_SIZE',             --the minimum number of bits for the blue channel of the accumulation buffer; defaults to 0.
		'SDL_GL_ACCUM_ALPHA_SIZE',            --the minimum number of bits for the alpha channel of the accumulation buffer; defaults to 0.
		'SDL_GL_STEREO',                      --whether the output is stereo 3D; defaults to off.
		'SDL_GL_MULTISAMPLEBUFFERS',          --the number of buffers used for multisample anti-aliasing; defaults to 0.
		'SDL_GL_MULTISAMPLESAMPLES',          --the number of samples used around the current pixel used for multisample anti-aliasing.
		'SDL_GL_ACCELERATED_VISUAL',          --set to 1 to require hardware acceleration, set to 0 to force software rendering; defaults to allow either.
		'SDL_GL_RETAINED_BACKING',            --not used (deprecated).
		'SDL_GL_CONTEXT_MAJOR_VERSION',       --OpenGL context major version.
		'SDL_GL_CONTEXT_MINOR_VERSION',       --OpenGL context minor version.
		'SDL_GL_CONTEXT_FLAGS',               --some combination of 0 or more of elements of the SDL_GLContextFlag enumeration; defaults to 0.
		'SDL_GL_CONTEXT_PROFILE_MASK',        --type of GL context (Core, Compatibility, ES). See SDL_GLProfile; default value depends on platform.
		'SDL_GL_SHARE_WITH_CURRENT_CONTEXT',  --OpenGL context sharing; defaults to 0.
		'SDL_GL_FRAMEBUFFER_SRGB_CAPABLE',    --requests sRGB capable visual; defaults to 0.
		'SDL_GL_CONTEXT_RELEASE_BEHAVIOR',    --sets context the release behavior. See SDL_GLContextReleaseFlag; defaults to FLUSH.
		-- getting 'unknown' for these:
		'SDL_GL_CONTEXT_RESET_NOTIFICATION',  --set context reset notification. See SDL_GLContextResetNotification; defaults to NO_NOTIFICATION.
		'SDL_GL_CONTEXT_NO_ERROR',
		'SDL_GL_FLOATBUFFERS',
		'SDL_GL_EGL_PLATFORM'
		--]=]
	} do
		local v = ffi.new'int[1]'
		xpcall(function()
			self.sdlAssert(sdl.SDL_GL_GetAttribute(sdl[k], v))
			print(k..' = '..v[0])
		end, function(err)
			print(k..' = '..err)
		end)
	end
print'done'
end

return App():run()
