#!/bin/bash

executable=$1

docker run \
    --rm \
    --volume "$(pwd)/../:/src" \
    --workdir "/src/Batch" \
    swift:5.3.1-amazonlinux2 \
    bash -cl "./Scripts/lambda/package.sh $executable"
