#!/usr/bin/env luajit
local sdl, SDLApp = require 'sdl.setup'(... or '2')
local App = SDLApp:subclass()
App.title = 'test'
return App():run()
