-- some useful functions for sdl audio
local sdl = require 'sdl'
local table = require 'ext.table'

local ctypeForSDLAudioFormat =  {
	-- TODO 'LSB' vs 'MSB' ...
	-- TODO how to determine unique types for each of these ...
	[sdl.AUDIO_U8] = 'uint8_t',
	[sdl.AUDIO_S8] = 'int8_t',
	[sdl.AUDIO_S16] = 'int16_t',
	[sdl.AUDIO_U16] = 'uint16_t',
	[sdl.AUDIO_S32] = 'int32_t',
	[sdl.AUDIO_F32] = 'float',

	[sdl.AUDIO_S16SYS] = 'int16_t',
	[sdl.AUDIO_U16SYS] = 'uint16_t',
	[sdl.AUDIO_S32SYS] = 'int32_t',
	[sdl.AUDIO_F32SYS] = 'float',
}

local sdlAudioFormatForCType = table.map(ctypeForSDLAudioFormat, function(v,k) return k,v end):setmetatable(nil)

return {
	ctypeForSDLAudioFormat = ctypeForSDLAudioFormat,
	sdlAudioFormatForCType = sdlAudioFormatForCType,
}
