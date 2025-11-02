#!/usr/bin/env luajit
local ffi = require 'ffi'
local table = require 'ext.table'
local sdl, SDLApp = require 'sdl.setup'(...)
local sdlAssertNonNull = require'sdl.assert'.nonnull
local App = SDLApp:subclass()
App.title = 'just for initialization'
function App:update()
	-- do clipboard stuff

-- [[
	-- do this here or once?
	local numMimeTypes = ffi.new'size_t[1]'
	local mimeTypesCstr = sdlAssertNonNull(sdl.SDL_GetClipboardMimeTypes(numMimeTypes))
-- annnd I get back none.
print('numMimeTypes', numMimeTypes[0])
print('mimeTypesCstr', mimeTypesCstr)
	local mimeTypes = table()
	for i=0,tonumber(numMimeTypes[0])-1 do
		local mt = ffi.string(mimeTypesCstr[i])
print('reading mimeType['..i..'] = '..mt)		
		mimeTypes[mt] = true
	end
print('done reading mimeTypes')	
	sdl.SDL_free(mimeTypesCstr)
--]]


-- [[ test clipboard text functionality
	local s = 'testing testing '..math.random(0,0xffffffff)
print('setting clipboard text to:', s)
	print('SDL_SetClipboardText', sdl.SDL_SetClipboardText(s))
	local result = sdl.SDL_HasClipboardText()
print('SDL_HasClipboardText', result)
print('SDL_HasClipboardData("text/plain")', sdl.SDL_HasClipboardData('text/plain'))
	if result then
		local text = sdl.SDL_GetClipboardText()
		if text == ffi.null then
print('SDL_GetClipboardText had null clipboard')
		else
print('SDL_GetClipboardText had:', ffi.string(text))
		end
	end
--]]

	-- then quit
	self:requestExit()
end
return App():run()
