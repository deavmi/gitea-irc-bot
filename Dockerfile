# Base image (for build)
FROM ubuntu:noble AS build
MAINTAINER "Tristan Brice Velloza Kildaire" "deavmi@redxen.eu"

# Don't allow interactive prompts when using apt
ARG DEBIAN_FRONTEND=noninteractive

# Activate arguments provided as build parameters
ARG BRANCH=master
ARG COMMIT=a6c1041208ca156e054aa1af9d72b3968cb9e093

# Get latest package lists
RUN apt update

# Install build dependencies
RUN apt install git -y
RUN apt install dub gcc -y
RUN apt install libssl-dev zlib1g-dev -y

