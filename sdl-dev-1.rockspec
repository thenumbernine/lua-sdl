package = "sdl"
version = "dev-1"
source = {
	url = "git+https://github.com/thenumbernine/lua-sdl.git"
}
description = {
	detailed = "SDL App foundation class",
	homepage = "https://github.com/thenumbernine/lua-sdl",
	license = "MIT"
}
dependencies = {
	"lua >= 5.1"
}
build = {
	type = "builtin",
	modules = {
		["sdl.app"] = "app.lua",
		["sdl.assert"] = "assert.lua",
		["sdl"] = "sdl.lua",
		["sdl.tests.test"] = "tests/test.lua"
	}
}
