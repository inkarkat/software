#!/bin/bash

SUDO=sudo; [ $EUID -eq 0 ] && SUDO=''

$SUDO ${SUDO:+--set-home} sh -c 'dpkg --add-architecture i386 && apt update'
