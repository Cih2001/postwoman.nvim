# Postwoman

Postwoman is a Neovim plugin that allows you to interact with REST APIs. With this plugin, you can call and examine your REST API directly from your favorite text editor.

## Requirement

- curl
- libyaml

## Installation

1.  Make sure to install libyaml.
    On mac:

    ```bash
    brew install libyaml
    ```

    Take note of the installation path. On my machine it's on `/opt/homebrew/Cellar/libyaml/0.2.5/`. On yours, it may be in a differect place.

2.  Install plugin with packer.
    ```
        use({
            "Cih2001/postwoman.nvim",
            rocks = {
                "lyaml",
                env = { YAML_DIR = "/home/linuxbrew/.linuxbrew/Cellar/libyaml/0.2.5/" },
            },
        })
    ```
