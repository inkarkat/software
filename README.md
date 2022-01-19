# Software

_Abstraction layer over various package managers (native, Python, npm, etc.) that allows selection, installation, and configuration of software packages._

## Motivation

Even with native Linux package management (e.g. _apt_ on Debian and Ubuntu), it is hard to record and reapply software selections across different systems. The raw software selections contain dependent libraries, meta-packages, and the baseline packages of the distribution, and these differ between package versions and distributions. So when moving from an older Ubuntu version to a newer on a new computer, one already needs a curated list of what explicitly got selected. Software that is not contained in the main software repository first needs additional meta-information applied before it can be installed.

Some software is not available through the native package management at all, but installed via third-party tools like _pip_ (Python) or _npm_ (JavaScript). Some applications have their own add-on / plugin concept (e.g. Firefox, but also Windows applications through _Wine_). And recently, distributions themselves have introduced modern package alternatives (_Flatpak_ and _Snap_).

And after all of this mess of getting the software, most applications need to be configured and tweaked, either through configuration files, via APIs, or manually with their user interface.

The number of systems has exploded; IT professionals don't just have a personal workstation and notebook, but also various virtual machines and cloud systems, or small devices (from _Chromebook_ through the _Raspberry Pi_ class to really small IoT devices that still run a minimal Linux). Some software can be persisted in operating system images or VM templates, but many systems are shared or provided by third parties, and therefore have to be customized from scratch, and potentially very often (e.g. when a test system is re-imaged every night).

## Description

This application offers the selection and installation of software from various sources, and can be easily extended with additional sources. A _software definition_ consists of one or more _items_ (i.e. packages from different sources or custom (pre-, post-)install instructions); _requirement checks_ can prevent inapplicable definitions from being offered. Individual software definitions are thematically grouped, and these _definition groups_ themselves can be organized in a directory tree. The user can interactively choose among those, and just get back a list of installation commands to be executed (this allows for greater control and easier reaction to any errors), or groups and selections can be passed along and get installed fully autonomously (for automation use cases).

The definitions and related data are stored in a separate directory tree, so different instantiations can be built (e.g. one for personal systems, one for cloud systems, or even just for a particular complex application). Custom installation actions can execute arbitrary command-lines for total flexibility. A new installation type can be added through a script that implements a simple internal API (obtain package list, is package installed, add package for installation, install added packages).

### Dependencies

* Bash, several of my own Unixhome libraries

### Installation

The `./bin` subdirectory is supposed to be added to `PATH`.
