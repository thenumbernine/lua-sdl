package = "sdlapp"
version = "dev-1"
source = {
	url = "git+https://github.com/thenumbernine/lua-sdlapp.git"
}
description = {
	detailed = "SDL App foundation class",
	homepage = "https://github.com/thenumbernine/lua-sdlapp",
	license = "MIT"
}
dependencies = {
	"lua >= 5.1"
}
build = {
	type = "builtin",
	modules = {
		["sdlapp.assert"] = "assert.lua",
		sdlapp = "sdlapp.lua",
		["sdlapp.tests.test"] = "tests/test.lua"
	}
}
