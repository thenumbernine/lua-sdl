#!/usr/bin/env luajit
local sdl, SDLApp = require 'sdl.setup'(...)
local App = SDLApp:subclass()
App.title = 'test'
return App():run()
