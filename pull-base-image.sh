#!/bin/bash
# Try pulling base image through proxy or mirror
docker pull node:24.18.0-alpine || \
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/node:24.18.0-alpine || \
docker pull docker.mirrors.ustc.edu.cn/library/node:24.18.0-alpine
