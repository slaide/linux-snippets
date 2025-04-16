# linux-snippets
useful code snippets relevant for linux desktop environments

files:
- _bashrc_: bashrc config file with some QoL stuff (may be placed in ``` $HOME/.bashrc```)
- _alacritty.toml_: config file for the [alacritty](https://alacritty.org) terminal emulator
- _inputrc_: input mapping file for bash, enables using \[opt/cmd\]+\[leftarrow/rightarrow\] to skip over words in the prompt (may be placed in ``` $HOME/.inputrc```)
- _ghostty.conf_: basic config file for the [ghostty](https://ghostty.org/) terminal emulator. currently only changes keybind to pass sigint instead of copy selection on control c if no text is selected.
- _python.makefile_: see python section of this document
- _tmux.conf_: basic [tmux](https://github.com/tmux/tmux) config file to enable mouse input
- _virtualbox.md_: some notes on virtualbox usage.
- _wezterm.lua_: basic [wezterm](https://wezfurlong.org/wezterm/index.html) terminal emulator config file that just increases font size.
- _rpi5-build-linux6.13rt.sh_: build script to compile the 6.13 linux kernel with realtime scheduling enabled for the rasberry pi 5 (rpi5)
- _micro_settings.json_: settings for [micro](https://micro-editor.github.io/), primarily enabling copy/paste to terminal clipboard

## python

the python makefile can be used to build python from source. tested on arm64 macos (macbook m1 pro) and arm64 linux (rpi5).

a test script to ensure this makefile works across python versions is, e.g.:
```
# from python.org/downloads/source

# 3.6 seems to not be supported on apple silicon (3.7+ seem supported)
gmake -f python.makefile PYTHON_VERSION=3.6.15  all -j
gmake -f python.makefile PYTHON_VERSION=3.7.17  all -j
gmake -f python.makefile PYTHON_VERSION=3.8.20  all -j
gmake -f python.makefile PYTHON_VERSION=3.9.21  all -j
gmake -f python.makefile PYTHON_VERSION=3.10.16 all -j
gmake -f python.makefile PYTHON_VERSION=3.11.11 all -j
gmake -f python.makefile PYTHON_VERSION=3.12.9  all -j
gmake -f python.makefile PYTHON_VERSION=3.13.2  all -j 

EVAL_STR="import sys;print('version:\n',sys.version,'\n',2+2)"
echo ${EVAL_STR} | bash python-3.6.15/bin/python3 -
echo ${EVAL_STR} | bash python-3.7.17/bin/python3 -
echo ${EVAL_STR} | bash python-3.8.20/bin/python3 -
echo ${EVAL_STR} | bash python-3.9.21/bin/python3 -
echo ${EVAL_STR} | bash python-3.10.16/bin/python3 -
echo ${EVAL_STR} | bash python-3.11.11/bin/python3 -
echo ${EVAL_STR} | bash python-3.12.9/bin/python3 -
echo ${EVAL_STR} | bash python-3.13.2/bin/python3 -
```

this script has been run on an m1 pro macbook and 3.7-3.13 work with this makefile.
