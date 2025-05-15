local ffi = require 'ffi'
local sdl = require 'sdl'

local function sdlGetError()
	local msgptr = sdl.SDL_GetError()
	-- prevent ffi.string(NULL) segfaults, here and in gl.get's string() function
	return msgptr == ffi.null and '(null)' or ffi.string(msgptr)
end

local function sdlAssert(result)
	if result then return end
	error('SDL_GetError(): '..sdlGetError())
end

local function sdlAssertZero(intResult)
	sdlAssert(intResult == 0)
	return intResult
end

local function sdlAssertNonZero(intResult)
	sdlAssert(intResult ~= 0)
	return intResult
end

local function sdlAssertNonNull(ptrResult)
	sdlAssert(ptrResult ~= ffi.null)
	return ptrResult
end

return {
	getError = sdlGetError,
	assert = sdlAssert,
	zero = sdlAssertZero,
	nonzero = sdlAssertNonZero,
	nonnull = sdlAssertNonNull,
}
