#!/bin/bash
# Copied from https://github.com/swift-server/swift-aws-lambda-runtime/blob/a2b5326671a7afc300f4527ad4782db8eca06b13/Examples/LambdaFunctions/scripts/package.sh
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftAWSLambdaRuntime open source project
##
## Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu

executable=$1

swift build --product "$executable" -c release

target=".build/lambda/$executable"
rm -rf "$target"
mkdir -p "$target"
cp ".build/release/$executable" "$target/"
# add the target deps based on ldd
ldd ".build/release/$executable" | grep swift | awk '{print $3}' | xargs cp -Lv -t "$target"
cd "$target"
ln -s "$executable" "bootstrap"
zip --symlinks lambda.zip *
