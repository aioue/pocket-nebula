# Changelog

## [1.5.0](https://github.com/aioue/pocket-nebula/compare/v1.4.1...v1.5.0) (2026-08-16)


### Features

* add shared devcontainer layer consumable by other repos ([321b203](https://github.com/aioue/pocket-nebula/commit/321b2031cf9395f0821a5284183275f1d834fe52))
* **devcontainer:** improve OpenNebula CLI config and container UX ([5d38986](https://github.com/aioue/pocket-nebula/commit/5d389866871287a4ff7c5ee6772f6ddd7a2e9e7c))
* **devcontainer:** improve OpenNebula CLI configuration and container UX ([9b35563](https://github.com/aioue/pocket-nebula/commit/9b35563ac8931218e20202b3086f9a3a41f304ac))
* **devcontainer:** surface error output when OpenNebula CLI connection test fails ([775f433](https://github.com/aioue/pocket-nebula/commit/775f433aa7c97d946678a2546318d083c816ae17))
* initial OpenNebula automation dev container ([f4b5c29](https://github.com/aioue/pocket-nebula/commit/f4b5c2965ebbbec0678f7f7c2a91d5c2c0fe2efe))
* share AGENTS.md core, git hooks and workaround tracking ([6235934](https://github.com/aioue/pocket-nebula/commit/6235934d9898bc3cb2d699e80c4d349ffdbb7697))
* share the devcontainer Cursor rule alongside AGENTS.md ([1e98758](https://github.com/aioue/pocket-nebula/commit/1e987586d2c648829cb89bf3a80472d25eddb640))


### Bug Fixes

* **ci:** find the release PR via the list endpoint, not search ([e4f02d7](https://github.com/aioue/pocket-nebula/commit/e4f02d72b765c22f55040e63a58b8501029d6650))
* **ci:** match parked workflow runs by conclusion, not status ([755b92e](https://github.com/aioue/pocket-nebula/commit/755b92e1ececfd36eb5818afd9c0c8fa2b7cefd1))
* **ci:** parse devcontainer.json as JSONC, not strict JSON ([1387066](https://github.com/aioue/pocket-nebula/commit/1387066c15d4020e478456152b131abb3b925e60))
* **ci:** pass --repo to gh in the release job ([df636ed](https://github.com/aioue/pocket-nebula/commit/df636ed7819186a014b0abd1eb0da63e27a65514))
* **ci:** publish the base image on release via a reusable workflow ([a6b5092](https://github.com/aioue/pocket-nebula/commit/a6b509272055caa9c0ab6e325fc8261e556c9a3a))
* **devcontainer:** restore automatic OpenNebula CLI detection and global installation ([1ee7a7b](https://github.com/aioue/pocket-nebula/commit/1ee7a7b7bb0e3c5eb3054a542ff72721806600ff))
* **githooks:** annotate vault-guard for shellcheck ([09fa59d](https://github.com/aioue/pocket-nebula/commit/09fa59de283a81e044400c2735a6c199c68157f2))
* **githooks:** stop the vault guard flagging its own source ([afc5deb](https://github.com/aioue/pocket-nebula/commit/afc5deb87ba2fcb1798fe5d1670ae23ecd3c9821))
* **image:** restore remoteUser, which the metadata LABEL had silently dropped ([9836f88](https://github.com/aioue/pocket-nebula/commit/9836f88d042b4636b0af1521e4db6a5e5e7261d3))


### Documentation

* **devcontainer:** add troubleshooting hints for OpenNebula CLI authentication ([8ade64f](https://github.com/aioue/pocket-nebula/commit/8ade64f4e0a9acdcc4c5380c80230812305e3081))


### Refactoring

* collapse shared-layer machinery into .devcontainer-shared/ ([7352549](https://github.com/aioue/pocket-nebula/commit/7352549a3bc6724326ce4077e08521e4ad8ef9f7))

## [1.4.1](https://github.com/aioue/pocket-nebula/compare/v1.4.0...v1.4.1) (2026-08-14)


### Bug Fixes

* **ci:** find the release PR via the list endpoint, not search ([aa10d50](https://github.com/aioue/pocket-nebula/commit/aa10d50a357ec1b834a768a78569e2b0f25d4064))
* **image:** restore remoteUser, which the metadata LABEL had silently dropped ([76e0125](https://github.com/aioue/pocket-nebula/commit/76e0125a5509aeccb4907730fd3fd6d3f8c32805))

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
