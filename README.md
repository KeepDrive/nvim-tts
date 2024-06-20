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
It's perhaps a bit unorthodox, in part due to how Tabletop handles external editors and its objects, I ended up opting with a somewhat clunky system where for each object has its own json file containing its name, guid and relative paths to script files; this is so that you can manage your code however you like, at the cost of potentially extra work manually adding paths to object files.
Additionally `require()` is supported by embedding a header into scripts that get sent to Tabletop that overloads the function and loads all the modules in. This works as long as requires strictly follow the `require("path/to/module/from/project/root")` format, tts.nvim won't be able to figure out any module names fetched dynamically and only recognises double-quoted strings as of right now. Modules can require other modules, cyclical dependencies that could work in regular Lua _might_ be loaded in an impromper order.

The plugin adds multiple vim commands:
- `TTSCreate` adds a local configuration file to mark the root of a project.
- `TTSStart` and `TTSStop` start and stop the TTS client/server system for the current project.
- `TTSPull` queries TTS for all the objects.
- `TTSPushAll` and `TTSPush` sends changes to TTS, the latter only sending files that were changed since last push.
- `TTSAdd` force adds the current file to the next push.
- `TTSExec <guid> <lua code>` executes Lua code inside TTS using the given object.
- `TTSView` creates a buffer with the code in the current buffer modified to have a header with `require()`-d code (useful for debugging since the header offsets the line count).

## To-do
I should probably consider rewriting the project system using LSP instead of what I ended up with.

## License
This project is licensed under the MIT license, see LICENSE
