#!/usr/bin/perl -w
use strict;

my $dbFile = "$ENV{HOME}/.feed2red/db";
my @confDirs = ("$ENV{HOME}/.feed2red/");

# config variables and their default values
my %confVars =
	(
	'RedServer' => '',
	'User' => '',
	'Password' => '',
	'Channel' => '',
	'FeedURL' => '',
	'CustomFeedTitle' => 'UNSET',
	'ShowTitle' => 'Y',
	'UseShare' => 'Y',
	'UseContentHash' => 'N',
	'ExpireDays' => 'N',
	'UseCurrentTime' => 'N',
	'UseBookmarks' => 'Y',
	'UseQuote' => 'N',
	);

my ($response, $feed, $title, $cTitle, $eTitle, $body, $expire, $id, $hash, $feedLink, $modified, $modUTC, $postUTC, $status, %feeds, %visited, %visitedToday, %error);

use LWP::UserAgent;
use XML::Feed;
use URI::Escape;
use HTML::Entities;
use Fcntl;
use SDBM_File;
use Digest::SHA qw(sha1_base64);
use Encode;

# read configuration
readConfig();

# connect to DB File
unless (tie(%visited, 'SDBM_File', $dbFile, O_RDWR | O_CREAT, 0644))
	{
	print STDERR "feed2red.pl: Couldn't open SDBM file '$dbFile': $!\n";
	print STDERR "feed2red.pl: Aborted.\n";
	exit(1);
	}

# set stuff for Red connection
my $red = LWP::UserAgent->new();
my $hed = HTTP::Headers->new();

# fix incorrect unicode characters in Atom feeds
$XML::Atom::ForceUnicode = 1;

# parse feeds
foreach my $norm (keys %feeds)
	{
	$feed = eval('XML::Feed->parse(URI->new($feeds{$norm}[0]{FeedURL}));');
	if (!defined($feed))
		{
		my $errstr = XML::Feed->errstr;
		if (!defined($errstr))
			{
			$errstr = '(No error message available from XML::Feed module.)';
			}
		print STDERR "feed2red.pl: Couldn't parse feed $feeds{$norm}[0]{FeedURL}: $errstr\n";
		print STDERR "feed2red.pl: Skipping " . scalar(@{$feeds{$norm}}) . " channel(s) this feed should be posted to.\n";
		$error{$norm} = 1;
		next;
		}
	$title = $feed->title;
	$title =~ s/^\s+|\s+$//g;

	$feedLink = $feed->link;

	foreach my $entry (reverse($feed->entries))
		{
		$hash = '';

		if (defined($entry->modified))
			{
			$modified = $entry->modified->epoch;
			$modUTC = $entry->modified->clone;
			$modUTC->set_time_zone('UTC');
			}
		elsif (defined($entry->issued))
			{
			$modified = $entry->issued->epoch;
			$modUTC = $entry->issued->clone;
			$modUTC->set_time_zone('UTC');
			}
		else
			{
			# if the feed doesn't define a modified or issued date, always
			# use 1 in order to avoid dupes
			$modified = 1;
			$modUTC = DateTime->now;
			}

		if (defined($entry->title))
			{
			$eTitle = $entry->title;
			$eTitle =~ s/^\s+|\s+$//g;
			}
		else
			{
			$eTitle = '';
			}

		$body = $entry->content->body;

		# post to Red
		foreach my $f (@{$feeds{$norm}})
			{
			# create hash only once per entry, and only if required
			if ($$f{UseContentHash} =~ /^y/i)
				{
				if ($body)
					{
					$hash = sha1_base64(encode('UTF-8', $body)) if $hash eq '';
					}
				else
					{
					$hash = 'X';
					}
				$id = "$norm $hash";
				}
			else
				{
				$id = "$norm " . $entry->id;
				}

			# remember we had that id this time
			$visitedToday{$id} = 1;

			# don't post entry if we already did that
			# check only now because some users might check by content
			# while others check by date
			next if ($visited{$id} and $visited{$id} >= $modified);

			# change opst time to now if desired
			if ($$f{UseCurrentTime} =~ /^y/i)
				{
				$postUTC = DateTime->now;
				}
			else
				{
				$postUTC = $modUTC;
				}

			$hed->authorization_basic($$f{User}, $$f{Password});
			$red->default_headers($hed);
			$status = '';
			if ($eTitle and $$f{ShowTitle} =~ /^y/i)
				{
				$status .= "\n[h3][url=" . $entry->link . "]${eTitle}[/url][/h3]\n";
				}
			if ($$f{UseQuote} =~ /^y/i)
				{
				$status .= '[quote]' . htmlToBbcode($body, $feedLink) . '[/quote]';
				}
			else
				{
				$status .= htmlToBbcode($body, $feedLink);
				}
			if ($$f{UseBookmarks} =~ /^y/i)
				{
				$status =~ s/\[url/\#\^\[url/g;
				}
			if ($$f{UseShare} =~ /^y/i)
				{
				if ($$f{CustomFeedTitle} ne 'UNSET')
					{
					$cTitle = $$f{CustomFeedTitle};
					}
				else
					{
					$cTitle = $title;
					}
				$status = "[share author='" . uri_escape_utf8($cTitle) . "' profile='$feedLink' link='" . $entry->link . "' posted='$modUTC']$status\[/share]";
				}
			if ($$f{ExpireDays} =~ /^\d+$/)
				{
				$expire = uri_escape_utf8("+$$f{ExpireDays} days");
				$response = $red->post("$$f{RedServer}/api/statuses/update?channel=$$f{Channel}&created=$postUTC&expire=$expire",
					[ status => $status ]);
				}
			else
				{
				$response = $red->post("$$f{RedServer}/api/statuses/update?channel=$$f{Channel}&created=$postUTC",
					[ status => $status ]);
				}
			if ($response->is_error)
				{
				print STDERR "feed2red.pl: Error posting to Red: " . $response->message . "\n";
				print STDERR "feed2red.pl: Skipping id $id\n";
				print STDERR "feed2red.pl: for channel $$f{Channel} on server $$f{RedServer}.\n";
				next;
				}

			# if we could post successfully to at least one of the channels
			# we call this feed entry done
			$visited{$id} = $modified;
			}
		}
	}

# remove links that are not in the feed anymore from our database
foreach $id (keys %visited)
	{
	next if exists($visitedToday{$id});
	# don't delete entries from database if we couldn't reach that feed
	$id =~ /^(.*?) /;
	next if $error{$1};
	delete($visited{$id});
	}

sub htmlToBbcode
	{
	my ($string, $baseURL) = @_;
	return '' unless $string;

	$baseURL =~ s,^(https?://.*?/).*,$1,;

	$string =~ s,<pre.*?>(.*?)</pre>,\[code]$1\[/code],sgi;
	
	# we don't want to do the rest of the changes within in the [code] parts
	# array @parts: even elements will contain the parts outside [code]
	# odd elements will be the code elements
	my @parts = split(/(\[code].*?\[\/code])/s, $string);
	my $i = -1;
	foreach (@parts)
		{
		$i++;
		# jump over odd elements
		next if $i % 2;
		# replace newlines by spaces
		s/\r//sg;
		s/\n/ /sg;
		# replace multiple spaces by one
		s/\s{2,}/ /g;
		# remove leading and trailing whitespace
		s/^\s*//;
		s/\s*$//;
		# remove scripts
		s,<script(\s.*?|)>.*?</script>,,gi;
		# remove xml (seen in feeds with HTML created by MS Office =:-0 )
		s,<xml(\s.*?|)>.*?</xml>,,gi;
		# remove style definitions
		s,<style(\s.*?|)>.*?</style>,,gi;

		# <h...> -> \n[h...]\n
		s,<h(\d)(\s.*?|)>(.*?)</h\d>,\n\[h$1]$3\[/h$1]\n,gi;
		# <b>, <i>, <u>, <center>, <hr>, <ol>, <table>, <tr>, <td>, <th>, <ul>
		# possibly closing tags with /, will be replaced by the same in bbcode
		# (but lowercase)
		s,<(/?)(b|i|u|center|hr|ol|table|tr|td|th|ul)(\s.*?|)>,\[\L$1$2],gi;
		# <li> -> [*]
		s,<li(\s.*?|)>,\[*],gi;
		# <em> -> [i]
		s,<(/?)em(\s.*?|)>,\[$1i],gi;
		# <strong> -> [b]
		s,<(/?)strong(\s.*?|)>,\[$1b],gi;
		# <cite>/blockquote -> [quote]
		s,<(cite|blockquote)(\s.*?|)>\s*<p>,\n[quote],gi;
		s,<(/?)(cite|blockquote)(\s.*?|)>,\n[$1quote],gi;
		# <del> -> [s]
		s,<(/?)del(\s.*?|)>,[$1s],gi;
		# <font color=...> -> [color]
		s,<font\s.*?color="(.*?)".*?>(.*?)</font>,\[color=$1]$2\[/color],gi;
		# <img> -> [img]
		s,<img\s.*?src="(.*?)".*?>,\[img]$1\[/img]\n\n,gi;
		# <iframe> -> [iframe]
		s,<iframe\s.*?src="(.*?)".*?>.*?</iframe>,\[iframe]$1\[/iframe],gi;
		# fix relative links in img and iframe tags
		s,\[(img]|iframe])(?!http)(.*?)\[/\1,\[$1$baseURL$2\[/$1,g;
		# <a href> -> [url]
		s,<a\s.*?href="\s*(.*?)\s*".*?>(.*?)</a>,\[url=$1]$2\[/url],gi;
		# fix relative links in url tags
		s,\[url=(?!http)(.*?)],\[url=$baseURL$1],g;
		# decode HTML entities like &nbsp;, &amp;, &auml; &#039; etc.
		$_ = decode_entities($_);
		# <br>,<div> -> newline
		s/<(br|div)(\s.*?|)>/\n/gi;
		# if the body begins with a <p>, don't create newlines
		s/^\s*<p(\s.*?|)>//i;
		# <p> -> two newlines
		s/<p(\s.*?|)>/\n\n/gi;
		# remove all other html tags (including </p> and </li>, if present)
		s/<.*?>//g;
		# try to remove greater numbers of newlines
		s,\n\n\n,\n\n,g;
		}
	return(join('', @parts));
	}

sub readConfig
	{
	my
		(
		%defConfig, %feedConfig, $curHash, $line
		);
	for (my $i=0; $i <= $#confDirs; $i++)
		{
		# don't carry defaults over to other directories
		%defConfig = %confVars;
		unless (chdir($confDirs[$i]))
			{
			print STDERR "feed2red.pl: Could not change to directory $confDirs[$i]: $!\n";
			print STDERR "feed2red.pl: Won't read config files there.\n";
			next;
			}
		foreach my $file (sort(<*.conf>, <*.feed>))
			{
			unless (open(FILE, $file))
				{
				print STDERR "feed2red.pl: Could not open file $file in directory $confDirs[$i] for reading: $!\n";
				print STDERR "feed2red.pl: Skipping this file.\n";
				next;
				}
			$line = 0;
			$curHash = undef;
LINE:
			while (<FILE>)
				{
				$line++;
				# remove comments
				s/^(.*?)#.*$/$1/;
				# additional confDirs can be set anywhere
				if (/^\s*confdir\s*=\s*(.*)\s*$/i)
					{
					push(@confDirs, $1);
					next;
					}
				if (/^\s*\[defaults\]\s*$/i)
					{
					# a new defaults section
					# if we were in a feed section before, save that feed
					if (defined($curHash) and $curHash == \%feedConfig)
						{
						saveFeed($file, $line, \%defConfig, \%feedConfig);
						}
					# Reset defaults
					%defConfig = %confVars;
					# switch hash to write to to %defConfig
					$curHash = \%defConfig;
					next;
					}
				if (/^\s*\[feed\]\s*$/i)
					{
					# a new feed section
					# if we were not in a defaults section before,
					# and if this isn't our first entry,
					# save the feed we read before
					if (defined($curHash) and $curHash != \%defConfig)
						{
						saveFeed($file, $line, \%defConfig, \%feedConfig);
						}
					# Set defaults
					%feedConfig = %defConfig;
					# switch hash to write to to %feedConfig
					$curHash = \%feedConfig;
					next;
					}

				# read config lines
				foreach my $key (keys %confVars)
					{
					if (/^\s*$key\s*=\s*(.*)\s*$/i)
						{
						$$curHash{$key} = $1;
						next LINE;
						}
					}
				}
			# save last feed
			if (defined($curHash) and $curHash == \%feedConfig)
				{
				saveFeed($file, $line, \%defConfig, \%feedConfig);
				}
			}
		}
	}

sub saveFeed
	{
	my ($file, $line, $defConfig, $feedConfig) = @_;
	my $normalized;

	foreach my $key (keys %confVars)
		{
		if ($$feedConfig{$key} eq '')
			{
			if ($$defConfig{$key} eq '')
				{
				print STDERR "feed2red.pl: Error in [FEED] section before line $line in file $file:\n";
				print STDERR "feed2red.pl: No $key line found, and no default for $key available from previous [DEFAULTS] section.\n";
				print STDERR "feed2red.pl: Skipping this feed.\n";
				return 0;
				}
			$$feedConfig{$key} = $$defConfig{$key};
			}
		}
	# we only want to fetch every feed once
	# we hope that interchanging http/https and having trailing slashes or not
	# will always give us the same feed
	$normalized = $$feedConfig{FeedURL};
	$normalized =~ s,^https?\://,,;
	$normalized =~ s,/+$,,;
	# copy the hash, because we have a reference here that will be overwritten
	my %hashCopy = %{$feedConfig};
	push(@{$feeds{$normalized}}, \%hashCopy);
	return 1;
	}
