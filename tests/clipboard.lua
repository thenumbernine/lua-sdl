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

	-- then quit
	self:requestExit()
end
return App():run()
