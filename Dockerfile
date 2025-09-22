# Base image (for build)
FROM ubuntu:noble AS build
MAINTAINER "Tristan Brice Velloza Kildaire" "deavmi@redxen.eu"

# Don't allow interactive prompts when using apt
ARG DEBIAN_FRONTEND=noninteractive

# Get latest package lists
RUN apt update

# Install build dependencies
RUN apt install dub gcc -y
RUN apt install libssl-dev zlib1g-dev -y

# Bring all source into here
COPY * .

# Perform build
RUN dub build

RUN touch 1
RUN ls -la && sleep 20
RUN pwd && sleep 20


# Base image (for deployment)
FROM ubuntu:noble AS base
COPY --from=build /1 /1
COPY --from=build /gitea-irc-bot /bin/bot
RUN chmod +x /bin/bot

# Don't allow interactive prompts when using apt
ARG DEBIAN_FRONTEND=noninteractive

# Needed for runtime-linked libraries for D-based
# applications
RUN apt update
RUN apt install libphobos2-ldc-shared106 -y

# We look for config.json here
WORKDIR /
CMD ["/bin/bot"]
