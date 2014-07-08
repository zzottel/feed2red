feed2red
========

A Perl script to read Atom/RSS feeds and post them to Red Matrix channels

For news and support, please join the Red Forum at
https://red.zottel.net/channel/feed2red .

Requirements
------------

feed2red.pl uses the following Perl modules:

* LWP::UserAgent
* XML::Feed
* URI::Escape
* HTML::Entities
* Fcntl
* SDBM_File
* Digest::SHA

You will probably have to install some of them. If you're not sure which,
just start feed2red.pl from the command line, and Perl will tell you.

These are all standard modules that should be available for installation
in every normal Linux distribution.

Quick start
-----------

* **Important:** Create a channel in the Red Matrix that you want to use
	for feeds. Don't just post them to your normal channel, because then
	all your contacts will receive the posts! Keep in mind that you might
	not be allowed to redistribute the feed contents. In most cases, it's
	a good idea not to have that channel listed in the directory, and to
	restrict its public posts to its connections.
* In the home directory of the user that will run feed2red.pl, create a
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
	them to your channel. When you run it first, it will post all entries
	that are currently in a feed (last ten posts in most feeds). On every
	subsequent call, it will only post new entries it hasn't posted yet.
* You might want to set up a cronjob for that.
	Type `crontab -e` and add a line like this:
	`0 * * * *   /path/to/feed2red.pl`
	(/path/to/ obviously replaced by the actual path to feed2red.pl.)
	This example will call feed2red.pl every hour.

More Details
------------

You can set every config value you want in a [DEFAULTS] section, even
FeedURL, though that doesn't make much sense in most cases. You can then
override them in each [FEED] section with values specific for that feed.

Every [FEED] section inherits everything from the latest [DEFAULTS]
section, but nothing from previous [FEED] sections.

Case doesn't matter. Comment sign is # and makes the rest of the line a
comment.

If you want the same feed to be posted to mutiple channels, create
multiple [FEED] sections with the same FeedURL, but different Channels.
feed2red.pl will parse the feed only once and then post it to all channels
where the FeedURL in the [FEED] section matches.

**Available config variables:**

**RedServer** (required, default empty)
The Red server to post to.

**User** (required, default empty)
The user name to use when authenticating to the Red server. This is the
email address you enter when logging in.

**Password** (required, default empty)
The password to use when authenticating to the Red server. Note that a #
in the password will be interpreted as the beginning of a comment. This is
a known bug, but it will be hard to solve for the case that someone might
want to write a comment to the end of the password line. For the time
being, please use passwords without hash signs (#). Please drop me a line
if this is unacceptable to you; I'll try to find a solution then.

**Channel** (required, default empty)
The nick name of the channel to post to. In
https://red.zottel.net/channel/zottelszeug, that would be zottelszeug

**FeedURL** (required, default empty)
The URL of the feed to parse. This must be the URL of an actual feed, not
the URL of a page that has a feed!

**ShowTitle** (optional, default Y)
If set to Y, the title of a feed entry will be added to the Red post. If
set to any other value, e.g. N, the title of a feed entry will be ignored.

**UseContentHash** (optional, default N)
If set to Y, the changed status of an entry is not determined by issued or
modified date, but by saving a hash of the contents of every entry. If the
contents were changed, the entry is posted again. Be careful, this might
lead to double posts if a feed contains ads that are different whenever we
fetch it, or other similarly dynamic content.

**UseShare** (optional, default Y)
If set to Y, the feed entries will be posted using Red's [share] tag. This
is useful if you want to have several feeds posted to the same channel, as
you then can see which feed a post originated from. If set to any other
value, e.g. N, the [share] tag is not used, which makes sense if the
contents of only one feed are posted to a channel.

**ExpireDays** (optional, default N)
If set to a number, posts from that feed will expire in Red after \<number\>
days. Otherwise, no expiry date is set (default). Note that this will only
work if Content Expiration is enabled in the Additional Features settings
of the channel.

**UseCurrentTime** (optional, default N)
If set to Y, instead of using the modified or issued dates of the feed,
the resulting post in Red will be dated with the current time when
feed2red.pl posts it. This is useful if you don't want the posts to be
moved down in your stream to the actual creation time of the feed item,
which might be far enough down that you won't ever see them. This has only
an effect on the creation time of the post itself. If UseShare is also
enabled, the time written to the [share] tag will still reflect the time
when the feed item was created/modified.

**UseBookmarks** (optional, default Y)
If set to Y, all [url] tags will be prepended with #^ so that they can be
used with Red's bookmarks feature. Set to any other value, e.g. N, if you
don't like the #^s in the text.

Here's a more complex example for a .conf file:

```
[DEFAULTS]
redserver=https://the.red.server
user=foo@bar.baz
password=sdhgkasd
channel=feeds

[FEED]
feedurl=http://hmpf.grmbl.com/feeds/rss/
# set Red post time to the time when feed2red.pl posts the item, not to
# the time when the feed item was created/modified
usecurrenttime=Y

[FEED]
feedurl=http://a.b.com/c/d
channel=abc # posted to different channel
# don't use [share] tag for this feed
useshare=N
# don't use bookmark tags
usebookmarks=n

[FEED]
feedurl=https://secure.sec/encfeed/atom.xml
# no channel variable, this feed will go to the feeds channel again!
# don't show entry titles
showtitle=N
# expire posts after 7 days
expiredays=7
```

If feed entries are later updated, and this update is reflected in a
changed issued or modified date, feed2red.pl will currently simply post
the entry again. If the feed doesn't have modified dates, or only the
contents are updated, not the date, feed2red.pl will currently ignore
updates to posts.

If you use UseContentHash, not the issued/modified date is relevant, but
whether the contents of the entry have changed. Still, if they have
changed, a new post is generated.

Features intended for more professional use
-------------------------------------------

feed2red.pl will read all files in a config directory that end in .conf or
.feed in alphabetical (ASCII) order. That means you could, for example,
create some files for a server called foo. foo.conf will hold the
[DEFAULTS] section, and in every foo_user1.feed foo_user2.feed etc., there
are a few feeds for certain users. feed2red.pl doesn't care which
configuration goes into a .conf or a .feed file, these are just names to
allow clearer file naming.

You can think of it like all config files in a config directory being
merged to one file in alphabetical order.

Note that when a new [DEFAULTS] section is encountered, all previous
defaults are reset. The same is true when feed2red.pl switches to another
config directory, i.e. [DEFAULTS] are not carried over from one directory
to another.

With `confDir=/additional/path/to/config/files/`, which can be set
anywhere in a config file and also multiple times, you can add additional
directories to scan for config files. This can be useful if you want to
use config files that are automatically written by some tool and need to
be within the root of a web server. Always keep in mind that these configs
contain unencrypted passwords, though!

Bugs
----

If you encounter any bugs, please report them at the Red Matrix forum
feed2red@red.zottel.net (this is NOT an email address!), file an issue at the
repository at https://github.com/zzottel/feed2red or just fix them and
create a pull request.
