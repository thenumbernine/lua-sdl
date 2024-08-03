## SDL App foundation class

[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

`sdl.lua` is so shorthand `require 'sdl'` will redirect to `require 'ffi.req' 'sdl'`.
From there, SDL library search path can be configured and overridden on a per-architecture and per-OS basis.
See the `ffi/load.lua` section in the [lua ffi bindings](https://github.com/thenumbernine/lua-ffi-bindings) project for more on this.

`app.lua` is a application class, for all deriving subclasses ([glapp](https://github.com/thenumbernine/lua-glapp), [imguiapp](https://github.com/thenumbernine/lua-imguiapp), etc).

-

This is tempt me further to move the 'glapp' stuff into the 'gl/app.lua' folder, and the 'imguiapp' into the 'imgui/app.lua' folder ...
