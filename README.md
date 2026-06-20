# EasyMTProto

A lightweight shell script to automatically install and configure the `mtg` MTProto v2 proxy on both Debian/Ubuntu (Systemd) and Alpine Linux (OpenRC). It helps to self-host own MTProto proxy for better privacy, completely free of annoying ads or sponsored channels. Works fine even on a tiny 128 MB RAM Alpine box. 

## Features

- Automatically detects and configures the environment for either Debian/Ubuntu or Alpine Linux.
- Allows to select a custom port (defaults to 443) and binds safely to `0.0.0.0` or dual-stack environments without network hangs. Comes handy for NAT VPS or if the port is in use.  
- Sets up native system services (`systemd` or `OpenRC`) to keep the proxy running seamlessly in the background.

## Quick Install

Run the following command as root:

```bash
wget -qO- [https://raw.githubusercontent.com/mathewskdaniel/EasyMTProto/main/mtproto-proxy-installer.sh](https://raw.githubusercontent.com/mathewskdaniel/EasyMTProto/main/mtproto-proxy-installer.sh) | bash
