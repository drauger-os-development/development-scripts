# development-scripts
Internal development scripts for working on Drauger OS


---
`build.sh`
---
Build an *.deb package from the files in the current directory. This requires:
 * a filesystem layout following the standard Linux filesystem layout
   * any folders not found in one of `bin, etc, usr, lib, lib32, lib64, libx32, dev, home, proc, root, run, sbin, sys, tmp, var, opt, srv, or DEBIAN` will not be included in the *.deb
   * It is heavily discouraged to use `dev, home, proc, root, run, sys, or tmp`, but they are supported in case they are needed.
   * See the Debian Package Maintainers guide on how to format the necessary control, prerm, postrm, preinst, and postinst files
 * You can also have `build.sh` run compilations or `make` programs for you before building the *.deb
 
Currently supports `amd64`, `arm64`, and `all` settings for the `Architecture` field in `DEBIAN/control`
A number of different versions of this script are in use. Do not be suprised if you find a version requiring some sort of input.


---
`make-iso`
---
Make an ISO from a given `chroot`. See `debootstrap` on how to make a `chroot` on your system`

This program requires two arguments:

 * Architecture
   * In order to support working on multiple CPU architectures, you must specify the architecture you want to build the ISO for.
 * Codename
   * In order to support working on beta, alpha, and stable versions of a given OS, you must specify the codename for the version of the OS you want to build an ISO for.
   
First time run of this program will run through a few prompts in order to generate a configuration file in `~/.config/drauger/`

In order for this program to work, have your `chroot` in a location with a directory hierarchy like: `~/desired/location/ARCH/CODENAME` with the entire `chroot` inside `CODENAME`, where `CODENAME` is the codename for the version of the OS contained, and `ARCH` is the CPU architecture for the OS contained.


---
`build-kernel`
---
Build a kernel for either `amd64` or `arm64` CPU architectures.

This program handles updating a local Linux kernel GitHub repo, generating configurations for a given CPU architecture, cleaning the repository, and building distributable binary builds of the Linux kernel. 

Usage:

`build-kernel [amd64|arm64|pull|stash|pop|clean] [config]`

Passing "arm64" or "amd64" will trigger a build of a new kernel for that arch.

Passing "config" along with a given arch will trigger the CLI config menu to appear.

Passing "pull" will trigger a git pull.

Passing "stash" will attempt to stash any changes you have made, so you can pull.

Passing "pop" will attempt to pop any changes you have made, so you can build with any changes necessary.

Passing "clean" will attempt to clean the local repo. It cannot be used with any other options.

"pull" and "config" cannot be used together. Default action in this instance is a git pull.

"stash" and "config" cannot be used together. Default action in this instance is a git stash.

"pop" and "config" cannot be used together. Default action in this instance is a git pop.



# Note
This program will run a first time config, just like `make-iso` to generate a different config file in the same folder as `make-iso` has it's config file: `~/.config/drauger/`

---
`update-package`
---
Update packages in a `reprepro` local repository.

`update-package` expects:

 * Input in the format `CODENAME <*.deb package file name>` on stdin, where `CODENAME` is the codename for the version of the OS you are targeting
 * A folder hierarchy in the format:
 
 ```
 parent directory
 |
 |- DEBS
    |
    |- *.deb packages here
 |- apt-repo
    |
    |- reprepro apt repo here
 |- update-package
 ```
 
 
 ---
 `total-dev-time`
 ---
 reads from a file and provides total development time. The file is written to by scripts which are not in this repo yet.
 This program is actually going to be phased out eventually in favor of a more robust solution with not only fewer errors but also more accurate timing.
 
 
 
 ---
 # Note to other Distro Maintainers
 These scripts are provided under GPL V2 with the intent of making it easier to get into making a distro. If you use these scripts, please contribute to their development here to help make everyone's lives better.