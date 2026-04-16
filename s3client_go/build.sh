#!/bin/bash
workDIR=$(dirname "$0");workDIR=`cd "$workDIR"; pwd`
#try to connect to google to determine whether user need to use proxy
    echo "Google is blocked, Go proxy is enabled: GOPROXY=https://goproxy.cn,direct"
    export GOPROXY="https://goproxy.cn,direct"
cd $workDIR
go mod tidy
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o s3client .
