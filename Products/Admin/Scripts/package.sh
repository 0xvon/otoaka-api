#!/bin/bash

executable=$1
workspace="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "-------------------------------------------------------------------------"
echo "preparing docker build image"
echo "-------------------------------------------------------------------------"
docker build . -t builder
echo "done"

echo "-------------------------------------------------------------------------"
echo "building \"$executable\" lambda"
echo "-------------------------------------------------------------------------"
docker run --rm -v "$workspace":/workspace -w /workspace/Products/Admin builder \
       bash -cl "./Scripts/package-on-docker.sh $executable"
echo "done"
