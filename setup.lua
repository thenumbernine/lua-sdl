--[[
like gl.setup
pass this an init arg

how about a number for now?
require 'sdl.setup''2'
require 'sdl.setup''3'

and it'll replace `require 'sdl'` and `require 'sdl.app'` accordingly

Returns the sdl lib and the sdl app associated with it.
--]]
return function(sdlname)
	sdlname = sdlname or '3'
	-- first set up `require 'sdl'`
	local sdl = require ('sdl.ffi.sdl'..sdlname)
	package.loaded.sdl = sdl
	package.loaded['sdl.sdl'] = sdl
	-- it is used by sdl.app
	-- then set up `require 'sdl.app'`
	local app = require ('sdl.app'..sdlname)
	package.loaded['sdl.app'] = app
	-- then return
	return sdl, app
end
