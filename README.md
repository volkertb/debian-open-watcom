# Debian Open Watcom v2 image

## What is this?

This builds and publishes a Docker container image that can be used to (cross-)compile programs in a CI/CD pipeline,
such as GitHub Actions Workflows. This is particularly useful for source code that requires the (Open) Watcom toolchain
to build, such as some open source DOS projects.

It can also be used as a [dev container](https://containers.dev) or as the base image of one.

Also included in this container image are the [JWasm](https://github.com/Baron-von-Riedesel/JWasm) and
[jwlink](https://github.com/Baron-von-Riedesel/jwlink) forks by Japheth a.k.a.
[Baron-von-Riedesel](https://github.com/Baron-von-Riedesel), since some projects can only be built with these tools
specifically.

## How to build locally

```shell
docker build . -t open-watcom-dev-container-v2
```

## Other toolchains

There is also a DJGPP variant: https://github.com/volkertb/debian-djgpp
