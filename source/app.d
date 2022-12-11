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
import std.file;
import core.stdc.stdlib : exit;

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
		notifySH(ircMessage);
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
			notifySH(ircMessage);
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
			notifySH(ircMessage);
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
			notifySH(ircMessage);
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
			notifySH(ircMessage);
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
//TODO: THis should have a lock on it (maybe shared which let's us automatically do it)
//such that we can have another thread replace it when a disconnect happens or just to reconnect it
//TODO: Birchwood handling of disconnects (check this)
IRCBot ircBot;

/* Configuration file */
JSONValue config;


string[] listenAddresses;
ushort listenPort;

bool hasNTFYSH = false;
string ntfyServer, ntfyChannel;

string serverHost;
ushort serverPort;
string nickname;
string channelName;


/** 
 * Sends a message to ntfy.sh (only if it is enabled)
 *
 * Params:
 *   message = the message to send to ntfy.sh
 */
void notifySH(string message)
{
	//TODO: Add support for fancier formatted NTFY.SH messages
	
	if(hasNTFYSH)
	{
		gprintln("Sending message to ntfy.sh ...");
		post(ntfyServer~"/"~ntfyChannel, message);
		gprintln("Sending message to ntfy.sh ... [done]");
	}
}

void main(string[] args)
{
	string configFilePath;

	/* If given an argument then use it as the configuration file */
	if(args.length == 2)
	{
		/* Configuration file path */
		configFilePath = args[1];
	}
	/* If we have more than two arguments then it is an error */
	else if(args.length > 2)
	{
		gprintln("Only one argument, the path to the configuration file, is allowed", DebugType.ERROR);
		exit(-1);
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

		/* Web hook server details */
		JSONValue webhookBlock = config["webhook"];
		JSONValue listenBlock = webhookBlock["listen"];
		JSONValue[] listenAddressesJSON = listenBlock["addresses"].array();
		foreach(JSONValue listenAddress; listenAddressesJSON)
		{
			/* Get the listening address */
			string listenAddressStr = listenAddress.str();
			listenAddresses~=listenAddressStr;
		}
		listenPort = cast(ushort)(listenBlock["port"].integer());

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

		gprintln("Your configguration is: \n"~config.toPrettyString());
	}
	catch(JSONException e)
	{
		gprintln("There was an error whilst parsing the config file:\n\n"~e.msg, DebugType.ERROR);
		exit(-1);
	}
	catch(ErrnoException e)
	{
		gprintln("There was a problem opening the configuration file: "~e.msg, DebugType.ERROR);
		exit(-1);
	}

	
	/* Configure IRC client */
	ConnectionInfo connInfo = ConnectionInfo.newConnection(serverHost, serverPort, nickname);
	ircBot = new IRCBot(connInfo);

	/* Connect to the server */
	ircBot.connect();

	/* Choose a nickname */
	Thread.sleep(dur!("seconds")(2));
	ircBot.command(new Message("", "NICK", nickname));

	/* Identify oneself */
    Thread.sleep(dur!("seconds")(2));
	//TODO: Clean this string up
    ircBot.command(new Message("", "USER", "giteabotweb giteabotweb irc.frdeenode.net :Tristan B. Kildaire"));
    
	/* Join the requested channel */
    Thread.sleep(dur!("seconds")(4));
	//TODO: Use the new `join()` method
    ircBot.command(new Message("", "JOIN", channelName));


	/* Setup the web server */
	HTTPServerSettings httpServerSettings = new HTTPServerSettings();
	httpServerSettings.port = listenPort;
	httpServerSettings.bindAddresses = listenAddresses;

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