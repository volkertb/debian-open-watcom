# Debian Open Watcom v2 image

## What is this?

This builds and publishes a Docker container image that can be used to (cross-)compile programs in a CI/CD pipeline,
such as GitHub Actions Workflows. This is particularly useful for source code that requires the (Open) Watom toolchain
to built, such as some open source DOS projects.

## How to build locally

```shell
docker build . -t open-watcom-dev-container-v2
```
