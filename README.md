feed2red
========

A Perl script to read Atom/RSS feeds and post them to a Red Matrix channel

Requirements
------------

feed2red.pl uses the following Perl modules:

* LWP::UserAgent
* XML::Feed
* URI::Escape
* HTML::Entities
* Fcntl
* SDBM_File

You will probably have to install some of them. If you're not sure which,
just start feed2red.pl from the command line, and Perl will tell you.

These are all standard modules that should be available for installation
in every normal Linux distribution.

Quick start
-----------

* Create a channel in the Red Matrix that you want to use for feeds.
* In the home directory of the user that will run feed2red.pl, create
	directory called .feed2red and make it readable only to that user:

```
cd
mkdir .feed2red
chmod 0700 .feed2red
```

* Change to the newly created directory and create a file called
	feed2red.conf with the following contents:

```
[DEFAULTS]
# replace the values with the configuration you need, obviously
RedServer=https://your.red.server
User=your@user.name # email address like at Red login
Password=yOuRrEdPaSsWoRd
# the Channel is the short nickname of the channel
# in https://red.zottel.net/channel/zottelszeug , it would be zottelszeug
Channel=redchannel

[FEED]
# the FeedURL is the actual address of a feed, NOT a normal web page that
# has a feed!
FeedURL=http://foo.bar/feed/atom.xml

# for every feed you want, add a [FEED] section
[FEED]
FeedURL=http://bar.baz/comments/feed/
```

* That's it! Call feed2red.pl, and it will grab the feeds and post
	them to your channel. You might want to set up a cronjob for that.
	Type `crontab -e` and add a line like this:
	`0 * * * *   /path/to/feed2red.pl`
	(/path/to/ obviously replaced by the actual path to feed2red.pl)
	This example will call feed2red.pl every hour.

More Details
------------

You can set every config value you want in a [DEFAULTS] section, even
FeedURL, though that doesn't make sense. You can then override them in
each [FEED] section with values specific for that feed.

Every [FEED] section inherits everything from the previous [DEFAULTS] section,
but nothing from previous [FEED] sections.

Case doesn't matter. Comment sign is # and makes the rest of the line a
comment.

If you want the same feed to be posted to mutiple channels, create
multiple [FEED] sections with the same FeedURL, but different Channels.
feed2red.pl will parse the feed only once and then post it to all channels
where the FeedURL in [FEED] section matches.

Available config variables

**RedServer** (required, default empty)
The Red server to post to.

**User** (required, default empty)
The user name to use when authenticating to the Red server. This is the
email address you enter when logging in.

**Password** (required, default empty)
The password to use when authenticating to the Red server.

**Channel** (required, default empty)
The nick name of the channel to post to. In
https://red.zottel.net/channel/zottelszeug, that would be zottelszeug

**FeedURL** (required, default empty)
The URL of the feed to parse. This must be the URL of an actual feed, not
the URL of a page that has a feed!

**ShowTitle** (optional, default Y)
If set to Y, the title of a feed entry will be added to the Red post. If
set to any other value, e.g. N, the title of a feed entry will be ignored.

**UseShare** (optional, default Y)
If set to Y, the feed entries will be posted using Red's [share] tag. This
is useful if you want to have several feeds posted to the same channel, as
you then can see which feed a post originated from. If set to any other
value, e.g. N, the [share] tag is not used, which makes sense if the
contents of only one feed are posted to a channel.

Here's a more complex example for a .conf file:

```
[DEFAULTS]
redserver=https://the.red.server
user=foo@bar.baz
password=sdhgkasd
channel=feeds

[FEED]
feedurl=http://hmpf.grmbl.com/feeds/rss/

[FEED]
feedurl=http://a.b.com/c/d
channel=abc # posted to different channel
# don't use [share] tag for this feed
useshare=N

[FEED]
feedurl=https://secure.sec/encfeed/atom.xml
# no channel variable, this feed will go to the feeds channel again!
# don't show entry titles
showtitle=N
```

Features intended for more professional use
-------------------------------------------

feed2red.pl will read all files in a config directory that end in .conf or
.feed in alphabetical (ASCII) order. That means you could, for example,
create some files for a server called foo. foo.conf will hold the
[DEFAULTS] section, and in every foo_user1.feed foo_user2.feed etc., there
are a few feeds for certain users. feed2red.pl doesn't care which
configuration goes into a .conf or a .feed file, these are just names to
allow clearer file naming.

Note that when a new [DEFAULTS] section is encountered, all previous
defaults are reset.

With `confDir=/additional/path/to/config/files/`, which can be set
anywhere in a config file and also multiple times, you can add additional
directories to scan for config files. This can be useful if you want to
use config files that are automatically written by some tool and need to
be within the root of a web server. Always keep in mind that these configs
contain unencrypted passwords, though!
