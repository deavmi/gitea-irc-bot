import std.stdio;
import birchwood;
import core.thread;
import vibe.d;
import std.json;
import std.string;

private class IRCBot : Client
{
	this(ConnectionInfo connInfo)
	{
		super(connInfo);
	}
}

void pullRequestHandler(HTTPServerRequest request, HTTPServerResponse response)
{

}

void commitHandler(HTTPServerRequest request, HTTPServerResponse response)
{
	//TODO: Add error handling for json parsing
	JSONValue json = parseJSON(request.json().toString());

	writeln(json);

	// Extract the commit
	JSONValue commitBlock = json["commits"].array()[0];
	string commitMessage = strip(commitBlock["message"].str());
	string commitURL = commitBlock["url"].str();
	string commitID = commitBlock["id"].str();

	JSONValue authorBlock = commitBlock["author"];
	string authorName = authorBlock["name"].str();
	string authorEmail = authorBlock["email"].str();

	response.writeBody("Yo");

	string ircMessage = "Commit: "~commitMessage~" ("~commitID~") by "~authorName~" ("~authorEmail~") ["~commitURL~"]";
	ircBot.channelMessage(ircMessage, "#tlang");
}

void issueHandler(HTTPServerRequest request, HTTPServerResponse response)
{

}

IRCBot ircBot;

void main()
{
	writeln("Edit source/app.d to start your project.");

	ConnectionInfo connInfo = ConnectionInfo.newConnection("fd08:8441:e254::5", 6667, "giteabotweb");

	ircBot = new IRCBot(connInfo);

	ircBot.connect();

	Thread.sleep(dur!("seconds")(2));
	ircBot.command(new Message("", "NICK", "giteabotweb"));

    Thread.sleep(dur!("seconds")(2));
    ircBot.command(new Message("", "USER", "giteabotweb giteabotweb irc.frdeenode.net :Tristan B. Kildaire"));
        
    Thread.sleep(dur!("seconds")(4));
    ircBot.command(new Message("", "JOIN", "#tlang"));


	/* TODO: Put vibe-d initialization here and make the client global in the module */
	HTTPServerSettings httpServerSettings = new HTTPServerSettings();
	httpServerSettings.port = 6969;
	httpServerSettings.bindAddresses = ["::"];

	URLRouter router = new URLRouter();


	router.post("/commit", &commitHandler);
	router.post("/issue", &issueHandler);
	router.post("/pullrequest", &pullRequestHandler);


	listenHTTP(httpServerSettings, router);

	/* Starts the vibe-d event engine web server on the main thread */
	runApplication();
}