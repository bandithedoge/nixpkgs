#!/usr/bin/env nix-shell
#!nix-shell -i python -p python3 python3Packages.looseversion common-updater-scripts nurl

import argparse
import json
import os
import re
from looseversion import LooseVersion
from subprocess import run

parser = argparse.ArgumentParser()
parser.add_argument("--lts", action="store_true")
parser.add_argument("--regex")
args = parser.parse_args()

nixpkgs_path = os.environ["PWD"]

attr = "incus"
file = "pkgs/by-name/in/incus/package.nix"
if args.lts:
    attr = "incus-lts"
    file = "pkgs/by-name/in/incus/lts.nix"

tags = (
    run(["list-git-tags", "--url=https://github.com/lxc/incus"], capture_output=True)
    .stdout.decode("utf-8")
    .splitlines()
)
tags = [t.lstrip("v") for t in tags]

latest_version = "0"
for tag in tags:
    if args.regex is not None and not re.match(args.regex, tag):
        continue

    if LooseVersion(tag) > LooseVersion(latest_version):
        latest_version = tag

current_version = (
    run(
        ["nix", "eval", "--raw", "-f", "default.nix", f"{attr}.version"],
        capture_output=True,
    )
    .stdout.decode("utf-8")
    .strip()
)

if LooseVersion(latest_version) <= LooseVersion(current_version):
    print("No update available")
    exit(0)

print(f"Found new version {latest_version} > {current_version}")

run(["update-source-version", attr, latest_version, f"--file={file}"])

file_content: str

with open(file, "r+") as f:
    file_content = f.read()
    file_content = re.sub(
        'vendorHash = "sha256-.*"',
        'vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="',
        file_content,
    )
    f.seek(0)
    f.write(file_content)

print("Generating new vendorHash")

latest_vendor_hash = (
    run(
        ["nurl", "--expr", f"(import {nixpkgs_path} {{}}).{attr}.goModules"],
        capture_output=True,
    )
    .stdout.decode("utf-8")
    .strip()
)

file_content = file_content.replace(
    "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", latest_vendor_hash
)

with open(file, "w") as f:
    f.write(file_content)

print("Done")
