gitea-irc-bot
=============

## Setup

You should setup the following webhooks on your Gitea instance:

1. `HOSTNAME:PORT/issue`
    * MIME type: `application/json`
    * Method: `POST`
    * Enable "Custom Events":
        * `Issues`
        * `Issue Labeled`
        * `Issue Comment`
        * `Issue Milestoned`
        * `Issue Assigned`
2. `HOSTNAME:PORT/commit`
    * MIME type: `application/json`
    * Method: `POST`
    * Enable "Custom Events":
        * `Push`