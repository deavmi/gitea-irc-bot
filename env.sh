#!/bin/sh

# Webhook configuration
export WEBHOOK__BINDADDRESS="0.0.0.0"
export WEBHOOK__PORT=8080

# IRC server
export IRC__HOST="pinewood.irc.bnet.eu.org"
export IRC__PORT=6667
export IRC__NICKNAME="GiteaBot"
export IRC__REALNAME="A Gitea bot written by deavmi"
export IRC__CHANNELS="tlang:#tlang;thing2:#thing2Chan"
export IRC__USERNAME="tbot"

# Ntfy.sh
export NTFY__ENDPOINT="http://ntfy.sh"
export NTFY__TOPIC="tlang_dev"