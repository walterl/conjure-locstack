# LocStack

Load the last Clojure exception's stack trace into Neovim's location list.

Status: "Works for me", but haven't been battled tested yet. Please report any
bugs you find!

## Installation

With [vim-plug](https://github.com/junegunn/vim-plug):

```
Plug 'walterl/conjure-locstack'
```

Requires [Conjure](nhttps://github.com/olical/conjure), connected to an nREPL server.

## Usage

```
:LocStack
```

**NOTE:** It takes upwards of 40 seconds for the command to complete. This is
due to the `stacktrace` nREPL operation taking so long to respond.

## Trivia

This was almost called "Loc stack and two useful functions".

## License

Copyright © 2022 Walter

Distributed under the [MIT License](./LICENSE.md).
