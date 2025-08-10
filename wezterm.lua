-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- change the configuration here (this will update live)
config.font_size = 18.0

-- and finally, return the configuration to wezterm
return config
