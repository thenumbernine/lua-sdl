local ffi = require 'ffi'
local sdl = require 'sdl'

local function sdlAssert(result)
	if result then return end
	local msg = ffi.string(sdl.SDL_GetError())
	error('SDL_GetError(): '..msg)
end

local function sdlAssertZero(intResult)
	sdlAssert(intResult == 0)
	return intResult
end

local function sdlAssertNonNull(ptrResult)
	sdlAssert(ptrResult ~= nil)
	return ptrResult
end

return {
	assert = sdlAssert,
	zero = sdlAssertZero,
	nonnull = sdlAssertNonNull,
}
