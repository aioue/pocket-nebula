# Changelog

## [1.4.0](https://github.com/aioue/pocket-nebula/compare/v1.3.1...v1.4.0) (2026-08-14)


### Features

* share the devcontainer Cursor rule alongside AGENTS.md ([0d9304f](https://github.com/aioue/pocket-nebula/commit/0d9304f6d065d13c93fc8ccea9c0395d593f7fe7))


### Bug Fixes

* **ci:** match parked workflow runs by conclusion, not status ([a872f25](https://github.com/aioue/pocket-nebula/commit/a872f251c33ff449c5ef28c05bfcc652ab2c4253))
* **ci:** pass --repo to gh in the release job ([dd95ebe](https://github.com/aioue/pocket-nebula/commit/dd95ebed59c65baff2d82e06f5c065a83e6cd6a8))

## [1.3.1](https://github.com/aioue/pocket-nebula/compare/v1.3.0...v1.3.1) (2026-08-14)


### Bug Fixes

* **ci:** parse devcontainer.json as JSONC, not strict JSON ([e6863ac](https://github.com/aioue/pocket-nebula/commit/e6863accc0d6fbfd50a2fae16128fb2a5390f636))
* **githooks:** annotate vault-guard for shellcheck ([95b9dfb](https://github.com/aioue/pocket-nebula/commit/95b9dfbb5bbe4137c3a50644e9395cd915d5bf2c))

## [1.3.0](https://github.com/aioue/pocket-nebula/compare/v1.2.0...v1.3.0) (2026-08-14)


### Features

* share AGENTS.md core, git hooks and workaround tracking ([e12cd1c](https://github.com/aioue/pocket-nebula/commit/e12cd1cbb9d11875949979c2690e4cc328587704))


### Bug Fixes

* **ci:** publish the base image on release via a reusable workflow ([57f44dc](https://github.com/aioue/pocket-nebula/commit/57f44dcd1ce91b33227b037bf020330222121865))
* **githooks:** stop the vault guard flagging its own source ([30c7f32](https://github.com/aioue/pocket-nebula/commit/30c7f329e393d3031d22a1cd7c86e4a95dd486f2))


### Refactoring

* collapse shared-layer machinery into .devcontainer-shared/ ([4834bc2](https://github.com/aioue/pocket-nebula/commit/4834bc21d5802b8ca8f43065a553f63b8b4091a9))

## [1.2.0](https://github.com/aioue/pocket-nebula/compare/v1.1.0...v1.2.0) (2026-08-14)


### Features

* add shared devcontainer layer consumable by other repos ([1556b73](https://github.com/aioue/pocket-nebula/commit/1556b73b50465cd7a5066773734677c09437f492))
* **devcontainer:** surface error output when OpenNebula CLI connection test fails ([775f433](https://github.com/aioue/pocket-nebula/commit/775f433aa7c97d946678a2546318d083c816ae17))


### Documentation

* **devcontainer:** add troubleshooting hints for OpenNebula CLI authentication ([8ade64f](https://github.com/aioue/pocket-nebula/commit/8ade64f4e0a9acdcc4c5380c80230812305e3081))
