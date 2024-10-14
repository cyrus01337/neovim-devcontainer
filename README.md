# Neovim Devcontainer

Devcontainers are a part of container-based development - you have a container
for your development environment and a container for testing a project in
production, both are used in tandem or, with the power of Docker in/outside
Docker, within the same container (whether that is good/bad I leave to your
discretion).

In a way this project acts as boilerplate for future devcontainers I choose to
publicise, and a way for me to use my development environment wherever I please
\- as are the pros of container-based development. There are also cons to this
approach, however, I recommend performing your own research on that matter.

## What is this for?

Containerising Neovim to use my personal Neovim configuration, of which all of
the plugins that I use have so many dependencies that setting them all up lead
to this. For the better (I hope).

This also acts as a base for other devcontainers like those that require [Bun](https://bun.sh/)
which I've used [here](https://github.com/cyrus01337/bun-devcontainer).

## Inclusions
- Whatever is included in the [Shell devcontainer](https://github.com/cyrus01337/shell-devcontainer)
- Docker outside of Docker (with user added to `docker` group)
- Obviously [Neovim](https://neovim.io/)
- [`dive`](https://github.com/wagoodman/dive) for Docker image debugging
- [`github-cli`](https://cli.github.com/) for GitHub repo manipulation
- [`go`](https://go.dev/) as a plugin dependency
- [`node`](https://nodejs.org/) as a plugin dependency and installer for [`live-server`](https://www.npmjs.com/package/live-server)
- [`python`](https://www.python.org/) as a plugin dependency, with `python3` linked to `python`
automatically
- [`stylua`](https://github.com/JohnnyMorganz/StyLua) for auto-formatting

## Author's Note
I regret nothing.
