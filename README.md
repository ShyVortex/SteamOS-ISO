# steamos-archive
This repository is currently a <b>work in progress</b>.
It aims to provide a comprehensive archive of SteamOS Recovery Images and related resources.

## What does it do
It automatically pulls the latest SteamOS Recovery Image, applies patches to make it compatible with Ventoy and makes it bootable on USB drives.

## Usage
Download the latest version of SteamOS from the [releases page](https://github.com/ShyVortex/steamos-archive/releases).
At the moment, the image is split in parts. Once all parts have been downloaded, open up the terminal and run the following command:

```shell
  cat steamos-recovery.img.part-* > steamos-recovery.img
```

This will recombine the parts into a single image file.
You can then move it to your Ventoy USB drive.
