import std.stdio;
import birchwood;
import core.thread;
import vibe.d;
import std.json;
import std.string;
import std.conv : to;

private class IRCBot : Client
{
	this(ConnectionInfo connInfo)
	{
		super(connInfo);
	}

	public override void onChannelMessage(Message msg, string, string)
	{
		// this.sendMessage("fok", "#tlang"BB);
		// channelMessage("fok", "#tlang");
	}
}

void commitHandler(HTTPServerRequest request, HTTPServerResponse response)
{
	/* Reply data */
	JSONValue replyJSON;
	int replyCode = 200;
	replyJSON["output"]="";

	try
	{
		//TODO: Add error handling for json parsing
		JSONValue json = parseJSON(request.json().toString());

		writeln(json.toPrettyString());

		// Extract the commit
		JSONValue commitBlock = json["commits"].array()[0];
		string commitMessage = strip(commitBlock["message"].str());
		string commitURL = commitBlock["url"].str();
		string commitID = commitBlock["id"].str();

		JSONValue authorBlock = commitBlock["author"];
		string authorName = authorBlock["name"].str();
		string authorEmail = authorBlock["email"].str();

		//FIXME: Reply with 200 or 500 on error
		
		string ircMessage = "Commit: "~commitMessage~" ("~commitID~") by "~authorName~" ("~authorEmail~") ["~commitURL~"]";
		ircBot.channelMessage(ircMessage, "#tlang");
	}
	catch(Exception e)
	{
		replyCode=500;
		replyJSON["output"]=e.toString();
	}
	
	response.writeJsonBody(replyJSON, 200);
}

void issueHandler(HTTPServerRequest request, HTTPServerResponse response)
{
	/* Reply data */
	JSONValue replyJSON;
	int replyCode = 200;
	replyJSON["output"]="";

	try
	{
		//TODO: Add error handling for json parsing
		JSONValue json = parseJSON(request.json().toString());

		writeln(json.toPrettyString());

		//Extract the type of action
		JSONValue issueBlock = json["issue"];
		string issueTitle = issueBlock["title"].str();
		string issueURL = issueBlock["url"].str();
		long issueID = issueBlock["id"].integer();
		string issueAction = json["action"].str();

		/* Opened a new issue */
		if(cmp(issueAction, "opened") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			ircBot.channelMessage("Opened issue '"~issueTitle~"' (#"~to!(string)(issueID)~") by "~username~" ["~issueURL~"]", "#tlang");
		}
		/* Closed an old issue */
		else if(cmp(issueAction, "closed") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			ircBot.channelMessage("Closed issue '"~issueTitle~"' (#"~to!(string)(issueID)~") by "~username~" ["~issueURL~"]", "#tlang");
		}
		/* Reopened an old issue */
		else if(cmp(issueAction, "reopened") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			ircBot.channelMessage("Reopened issue '"~issueTitle~"' (#"~to!(string)(issueID)~") by "~username~" ["~issueURL~"]", "#tlang");
		}
		/* Added a comment */
		else if(cmp(issueAction, "created") == 0)
		{
			JSONValue commentBlock = json["comment"];
			string commentBody = commentBlock["body"].str();

			ulong commentLen = commentBody.length;

			if(!(commentLen <= 30))
			{
				commentBody=commentBody[0..31]~"...";
			}

			JSONValue userBlock = commentBlock["user"];
			string username = userBlock["username"].str();

			ircBot.channelMessage("New comment '"~commentBody~"' by "~username~" on issue #"~to!(string)(issueID)~" ["~issueURL~"]", "#tlang");		
		}
	}
	catch(Exception e)
	{
		replyCode=500;
		replyJSON["output"]=e.toString();
	}
	
	response.writeJsonBody(replyJSON, 200);
}

void pullRequestHandler(HTTPServerRequest request, HTTPServerResponse response)
{
	/* Reply data */
	JSONValue replyJSON;
	int replyCode = 200;
	replyJSON["output"]="";

	try
	{
		//TODO: Add error handling for json parsing
		JSONValue json = parseJSON(request.json().toString());

		writeln(json.toPrettyString());
	}
	catch(Exception e)
	{
		replyCode=500;
		replyJSON["output"]=e.toString();
	}
	
	response.writeJsonBody(replyJSON, 200);
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

	/* Create a router and add the supported routes */
	URLRouter router = new URLRouter();
	router.post("/commit", &commitHandler);
	router.post("/issue", &issueHandler);
	router.post("/pullrequest", &pullRequestHandler);

	/* Attach the router to the HTTP server settings */
	listenHTTP(httpServerSettings, router);

	/* Starts the vibe-d event engine web server on the main thread */
	runApplication();
}