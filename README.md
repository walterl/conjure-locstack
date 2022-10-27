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

Load last stack trace into location list:

    :LocStack

Load stack trace from register `x` (defaults to `"`) into location list:

    :LocStackReg x

The value in the register must be as returned by `(-> ex :Throwable->map
:trace)`, verbatim.

This allows you to yank exception stack traces from logs, and load them into
the location list.

## Trivia

This was almost called "Loc stack and two useful functions".

## License

Copyright © 2022 Walter

Distributed under the [MIT License](./LICENSE.md).
