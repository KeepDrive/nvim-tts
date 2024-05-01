# tts.nvim
Neovim plugin for Tabletop Simulator scripting

## Requirements
- Neovim 0.9.5

## Setup
As with any plugin, this can be installed with your favourite plugin manager.
For example, lazy.nvim:
```lua
require("lazy").setup({
  "KeepDrive/tts.nvim",
})
```

## Usage
It's perhaps a bit unorthodox, in part due to how Tabletop handles external editors and its objects, I ended up opting with a somewhat clunky system where for each object has its own json file containing its name, guid and relative paths to script files; this is so that you can manage your code however you like, at the code of potentially extra work manually adding paths to object files.

The plugin adds multiple vim commands:
- `TTSCreate` adds a local configuration file to mark the root of a project.
- `TTSStart` and `TTSStop` start and stop the TTS client/server system for the current project.
- `TTSPull` queries TTS for all the objects.
- `TTSPushAll` and `TTSPush` sends changes to TTS, the latter only sending files that were changed since last push.
- `TTSAdd` force adds the current file to the next push.
- `TTSExec <guid> <lua code>` executes Lua code inside TTS using the given object.

## To-do
I should probably consider rewriting the plugin system using LSP instead of what I ended up with.

## License
This project is licensed under the MIT license, see LICENSE
