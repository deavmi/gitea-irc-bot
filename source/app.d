import std.stdio;
import birchwood;
import core.thread;
import vibe.d;
import std.json;
import std.string;
import std.conv : to;
import std.net.curl;
import gogga;
import std.exception;


/** 
 * TODO list
 *
 * 1. Fix the stripping of bad characters like \r\n etc etc in messages
 */

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
		/* Extract the received JSON */
		JSONValue json = parseJSON(request.json().toString());
		writeln(json.toPrettyString());

		/* Extract the commit */
		JSONValue commitBlock = json["commits"].array()[0];
		string commitMessage = strip(commitBlock["message"].str());
		string commitURL = commitBlock["url"].str();
		string commitID = commitBlock["id"].str();

		JSONValue authorBlock = commitBlock["author"];
		string authorName = authorBlock["name"].str();
		string authorEmail = authorBlock["email"].str();
		
		string ircMessage = "Commit: "~commitMessage~" ("~commitID~") by "~authorName~" ("~authorEmail~") ["~commitURL~"]";
		ircBot.channelMessage(ircMessage, "#tlang"); //TODO: Add IRC error handling


		/* Send message to NTFY server */
		post(ntfyServer~"/"~ntfyChannel, ircMessage);
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
		/* Extract the received JSON */
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
			
			//TODO: Add IRC error handling
			string ircMessage = "Opened issue '"~issueTitle~"' (#"~to!(string)(issueID)~") by "~username~" ["~issueURL~"]";
			ircBot.channelMessage(ircMessage, channelName);

			/* Send message to NTFY server */
			post(ntfyServer~"/"~ntfyChannel, ircMessage);
		}
		/* Closed an old issue */
		else if(cmp(issueAction, "closed") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			//TODO: Add IRC error handling
			string ircMessage = "Closed issue '"~issueTitle~"' (#"~to!(string)(issueID)~") by "~username~" ["~issueURL~"]";
			ircBot.channelMessage(ircMessage, channelName);

			/* Send message to NTFY server */
			post(ntfyServer~"/"~ntfyChannel, ircMessage);
		}
		/* Reopened an old issue */
		else if(cmp(issueAction, "reopened") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			//TODO: Add IRC error handling
			string ircMessage = "Reopened issue '"~issueTitle~"' (#"~to!(string)(issueID)~") by "~username~" ["~issueURL~"]";
			ircBot.channelMessage(ircMessage, channelName);

			/* Send message to NTFY server */
			post(ntfyServer~"/"~ntfyChannel, ircMessage);
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

			//TODO: Add IRC error handling
			string ircMessage = "New comment '"~commentBody~"' by "~username~" on issue #"~to!(string)(issueID)~" ["~issueURL~"]";
			ircBot.channelMessage(ircMessage, channelName);		

			/* Send message to NTFY server */
			post(ntfyServer~"/"~ntfyChannel, ircMessage);
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
		/* Extract the received JSON */
		JSONValue json = parseJSON(request.json().toString());
		writeln(json.toPrettyString());

		//TODO: Implement me
	}
	catch(Exception e)
	{
		replyCode=500;
		replyJSON["output"]=e.toString();
	}
	
	response.writeJsonBody(replyJSON, 200);
}


/* IRC client */
IRCBot ircBot;

/* Configuration file */
JSONValue config;


bool hasNTFYSH = false;
string ntfyServer, ntfyChannel;

string serverHost;
ushort serverPort;
string nickname;
string channelName;


import std.file;

void main(string[] args)
{
	string configFilePath;

	/* If given an argument then use it as the configuration file */
	//TODO: Don't allow more than 1 argument
	if(args.length == 2)
	{
		/* Configuration file path */
		configFilePath = args[1];
	}
	/* If we have more than two arguments then it is an error */
	else if(args.length > 2)
	{
		gprintln("Only one argument, the path to the configuration file, is allowed", DebugType.ERROR);
	}
	/* If there are no arguments, assume default config.json file */
	else
	{
		/* Set to the default config path */
		configFilePath = "config.json";
	}

	try
	{
		File configFile;
		configFile.open(configFilePath);

		ubyte[] configData;
		configData.length = configFile.size();
		configData = configFile.rawRead(configData);
		configFile.close();

		/* Parse the configuration */
		config = parseJSON(cast(string)configData);

		/* IRC server details */
		JSONValue ircBlock = config["irc"];
		serverHost = ircBlock["host"].str();
		serverPort = cast(ushort)(ircBlock["port"].integer());
		nickname = ircBlock["nickname"].str();
		channelName = ircBlock["channel"].str();


		/* Attempt to parse ntfy.sh configuration */
		try
		{
			JSONValue configNTFY = config["ntfy"];

			ntfyServer = configNTFY["endpoint"].str();
			ntfyChannel = configNTFY["topic"].str();

			hasNTFYSH = true;
		}
		catch(JSONException e)
		{
			gprintln("Not configuring NTFY as config is partially broken:\n\n"~e.msg, DebugType.WARNING);
		}

		gprintln(config.toPrettyString());


		
	}
	catch(JSONException e)
	{
		gprintln("There was an error whilst parsing the config file:\n\n"~e.msg, DebugType.ERROR);
		//FIXME: Add exit
		// exit(1);
	}
	catch(ErrnoException e)
	{
		gprintln("Invalid JSON within the configuration or missing needed keys: \n\n"~e.msg, DebugType.ERROR);
		//FIXME: Add exit
		// exit(1);
	}

	

	ConnectionInfo connInfo = ConnectionInfo.newConnection(serverHost, serverPort, nickname);

	ircBot = new IRCBot(connInfo);

	ircBot.connect();

	Thread.sleep(dur!("seconds")(2));
	ircBot.command(new Message("", "NICK", nickname));

    Thread.sleep(dur!("seconds")(2));
    ircBot.command(new Message("", "USER", "giteabotweb giteabotweb irc.frdeenode.net :Tristan B. Kildaire"));
        
    Thread.sleep(dur!("seconds")(4));
    ircBot.command(new Message("", "JOIN", channelName));


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