#!/bin/sh

if [ ! $CI ]; then
  export PATH=$PATH:/opt/homebrew/bin
  swift-format -r ../Orgel ../Orgel_Tests ../Orgel_Sample -i
fi
