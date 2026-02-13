## SDL App foundation class

[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

# Usage

The SDL version can be picked similar to my [gl bindings](http://github.com/thenumbernine/lua-gl)'s `require 'gl.setup' 'version'`:
`local sdl, SDLApp = require 'sdl.setup' '2'` will set up the subsequent `require 'sdl'` and `require 'sdl.app'`'

This will override the following packages:
`local sdl = require 'sdl'`
`local SDLApp = require 'sdl.app'`

# Or if you want to load whatever is the latest fad:

`require 'sdl'` will load the `sdl.lua` file which will redirect to `require 'sdl.ffi.sdl3'`.
From there, SDL library search path can be configured and overridden on a per-architecture and per-OS basis.
See the `ffi/load.lua` section in the [lua ffi bindings](https://github.com/thenumbernine/lua-ffi-bindings) project for more on this.

`require 'sdl.app'` will load `app.lua`, which directs to `app3.lua`. 
This is a Lua application class, for all deriving subclasses ([gl.app](https://github.com/thenumbernine/lua-gl), [vk.app](https://github.com/thenumbernine/lua-vk), [imgui.app](https://github.com/thenumbernine/lua-imgui), [wgpu.app](https://github.com/thenumbernine/lua-wgpu), etc).

# Or if you want to require the library and application files directly:

If you want specifically SDL3 support:
- use `require 'sdl.ffi.sdl3'` to load the SDL3 library
- use `require 'sdl.app3'` to load the SDL3 application class.

If you want specifically SDL2 support:
- use `require 'sdl.ffi.sdl2'` to load the SDL2 library
- use `require 'sdl.app2'` to load the SDL2 application class.
