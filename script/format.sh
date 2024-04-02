#!/bin/sh

if [ ! $CI ]; then
  export PATH=$PATH:/opt/homebrew/bin
  swift-format -r ./Sources ./Tests ./Examples -i
fi
