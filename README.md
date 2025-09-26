# omazzite &nbsp; [![bluebuild build badge](https://github.com/r-dson/omazzite/actions/workflows/build.yml/badge.svg)](https://github.com/r-dson/omazzite/actions/workflows/build.yml)

This is a custom atomic Fedora image, built upon the `bazzite-dx-nvidia` base. It provides Hyprland desktop environment, based on the [Omarchy](https://omarchy.org) implementation and patterns, with the configuration of [omadora](https://github.com/elpritchos/omadora).

## Installation

> [!WARNING]  
> This is an experimental, try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/r-dson/omazzite:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/r-dson/omazzite:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/r-dson/omazzite
