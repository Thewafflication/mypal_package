# Mypal WPM package

This repository builds signed [WPM](https://github.com/Thewafflication/wpm) packages from the latest binary release of [Mypal](https://github.com/Feodor2/Mypal68). It does not compile Mypal.

The builder discovers the latest upstream GitHub release, downloads the matching English ZIP, verifies GitHub's published SHA-256 digest when available, and packages it for `x86` or `x64`. Installation copies Mypal to `%ProgramFiles%\Mypal\<version>` and creates an all-users desktop shortcut. Removal deletes that shortcut only when it still targets the package being removed.

## Install with WPM

From an elevated PowerShell session:

```powershell
wpm repo add https://github.com/Thewafflication/mypal_package/releases/latest/download
wpm update
wpm install mypal
```

Before the first installation, trust the release key:

```powershell
Invoke-WebRequest https://github.com/Thewafflication/mypal_package/releases/latest/download/wpm-release.public -OutFile wpm-release.public
wpm trust add wpm-release.public
```

## Build locally

Install WPM, then run:

```powershell
.\scripts\Build-MypalPackage.ps1 -Architecture x86 -DebugPackage
.\scripts\Build-MypalPackage.ps1 -Architecture x64 -DebugPackage
```

For a signed build, pass `-SigningKey <path-to-wpm-private-key>`. Packages are written to `out\packages`.

## GitHub release setup

Add the `WPM_RELEASE_PRIVATE_KEY` repository secret containing the private key corresponding to `release_keys/wpm-release.public`. Replace the checked-in public key if this repository will use a different signing identity.

Pushes and pull requests build unsigned debug packages. A scheduled run checks upstream daily and publishes signed packages; manually running the workflow with `publish=true` does the same immediately. Publishing is idempotent for a given upstream version.

Mypal is redistributed under MPL-2.0. This packaging repository is not affiliated with the Mypal project.
