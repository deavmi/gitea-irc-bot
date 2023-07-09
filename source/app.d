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

import gogga;


private __gshared GoggaLogger logger;
static this()
{
	logger = new GoggaLogger();
}


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

	/* Channel to eventually send to */
	string toChannel;

	try
	{
		/* Extract the received JSON */
		JSONValue json = parseJSON(request.json().toString());
		writeln(json.toPrettyString());

		/* Extract the commits (if any) */
		JSONValue[] commits = json["commits"].array();

		/** 
		 * A tag push will have no commits,
		 * for now ignore those. Only react
		 * if we have at least one commit and
		 * then react to the first one listed.
		 */
		if(commits.length > 0)
		{
			/* Extract the commit */
			JSONValue commitBlock = json["commits"].array()[0];
			string commitMessage = strip(commitBlock["message"].str());
			string commitURL = commitBlock["url"].str();
			string commitID = commitBlock["id"].str();

			JSONValue authorBlock = commitBlock["author"];
			string authorName = authorBlock["name"].str();
			string authorEmail = authorBlock["email"].str();

			string repositoryName = json["repository"]["full_name"].str();
		
			/* Extract JUST the repository's name */
			toChannel = associations[json["repository"]["name"].str()];
			
			string ircMessage = bold("["~repositoryName~"]")~setForeground(SimpleColor.GREEN)~" New commit "~resetForegroundBackground()~commitMessage~" ("~commitID~") by "~italics(authorName)~" ("~authorEmail~") ["~underline(commitURL)~"]";
			ircBot.channelMessage(ircMessage, toChannel); //TODO: Add IRC error handling

			/* Send message to NTFY server */
			notifySH(ircMessage);
		}
		else
		{
			logger.warn("Ignoring /commit triggered but with empty commits");
		}
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

	/* Channel to eventually send to */
	string toChannel;

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
		string repositoryName = issueBlock["repository"]["full_name"].str();

		/* Extract JUST the repository's name */
		toChannel = associations[json["repository"]["name"].str()];

		/* Opened a new issue */
		if(cmp(issueAction, "opened") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			//TODO: Add IRC error handling
			string ircMessage = bold("["~repositoryName~"]")~setForeground(SimpleColor.GREEN)~" Opened issue"~resetForegroundBackground()~" '"~issueTitle~"' "~bold("#"~to!(string)(issueID))~" by "~italics(username)~" ["~underline(issueURL)~"]";
			ircBot.channelMessage(ircMessage, toChannel);

			/* Send message to NTFY server */
			notifySH(ircMessage);
		}
		/* Closed an old issue */
		else if(cmp(issueAction, "closed") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			//TODO: Add IRC error handling
			string ircMessage = bold("["~repositoryName~"]")~setForeground(SimpleColor.RED)~" Closed issue"~resetForegroundBackground()~" '"~issueTitle~"' on issue "~bold("#"~to!(string)(issueID))~" by "~italics(username)~" ["~underline(issueURL)~"]";
			ircBot.channelMessage(ircMessage, toChannel);

			/* Send message to NTFY server */
			notifySH(ircMessage);
		}
		/* Reopened an old issue */
		else if(cmp(issueAction, "reopened") == 0)
		{
			JSONValue userBlock = issueBlock["user"];
			string username = userBlock["username"].str();
			
			//TODO: Add IRC error handling
			string ircMessage = bold("["~repositoryName~"]")~setForeground(SimpleColor.GREEN)~" Reopened issue"~resetForegroundBackground()~" '"~issueTitle~"' "~bold("#"~to!(string)(issueID))~" by "~italics(username)~" ["~underline(issueURL)~"]";
			ircBot.channelMessage(ircMessage, toChannel);

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
			string ircMessage = bold("["~repositoryName~"]")~" "~setForeground(SimpleColor.GREEN)~"New comment"~resetForegroundBackground()~" '"~italics(commentBody)~"' by "~italics(username)~" on issue "~bold("#"~to!(string)(issueID))~" "~issueTitle~" ["~underline(issueURL)~"]";
			ircBot.channelMessage(ircMessage, toChannel);		

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
string[] channels;
string[string] associations;

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
		logger.info("Sending message to ntfy.sh ...");
		post(ntfyServer~"/"~ntfyChannel, message);
		logger.info("Sending message to ntfy.sh ... [done]");
	}
}

void main()
{
	string configFilePath;

	import std.process : environment;

	/* If given an environment variable then use it as the configuration file */
	if(environment.get("GIB_CONFIG") !is null)
	{
		/* Configuration file path */
		configFilePath = environment.get("GIB_CONFIG");
	}
	/* If there is no environment variable, assume default config.json file */
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

		/** 
		 * Mapping between `repo -> #channel`
		 *
		 * Extract from the JSON, build the map
		 * and also construct a list of channels
		 * 9which we will use later to join
		 */
		JSONValue[string] channelAssociations = ircBlock["channels"].object();
		foreach(string repoName; channelAssociations.keys())
		{
			associations[repoName] = channelAssociations[repoName].str();
			channels ~= associations[repoName];
		}



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
			logger.warn("Not configuring NTFY as config is partially broken:\n\n"~e.msg);
		}

		logger.info("Your configuration is: \n"~config.toPrettyString());
	}
	catch(JSONException e)
	{
		logger.error("There was an error whilst parsing the config file:\n\n"~e.msg);
		exit(-1);
	}
	catch(ErrnoException e)
	{
		logger.error("There was a problem opening the configuration file: "~e.msg);
		exit(-1);
	}

	
	/* Configure IRC client */
	ConnectionInfo connInfo = ConnectionInfo.newConnection(serverHost, serverPort, nickname, "tbot", "TLang Bot");

	/* Set fakelag to none */
	connInfo.setFakeLag(0);

	/* Create a new IRC bot instance */
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
    
	/* Join the requested channels */
    Thread.sleep(dur!("seconds")(4));
    ircBot.joinChannel(channels);


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
