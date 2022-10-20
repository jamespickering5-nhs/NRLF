#!/bin/bash

function _make_help() {
  echo
  echo "nrlf make <command> [options]"
  echo
  echo "commands:"
  echo "  help          - this help screen"
  echo "  build         - Builds the code"
  echo "  clean         - Cleans the artefacts"
  echo "  install       - Setup local dependencies"
}

function _make() {
  command=$1
  case $command in
    "build") _build ;;
    "clean") _clean ;;
    "install") _install ;;
    *) _make_help ;;
  esac
}

function _build() {
  find $root -name make.sh | xargs -I % bash -c 'cd "$(dirname %)" && ./make.sh build'
}

function _clean() {
  find $root -name make.sh | xargs -I % bash -c 'cd "$(dirname %)" && ./make.sh clean'
}

function _install() {
  pipenv install --dev || return 1
}
