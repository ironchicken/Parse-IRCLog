
package Parse::IRCLog;
use Parse::IRCLog::Result;

use strict;
use warnings;

use Carp;

=head1 NAME

Parse::IRCLog -- parse internet relay chat logs

=head1 VERSION

version 1.10

 $Id: IRCLog.pm,v 1.6 2005/07/02 00:11:55 rjbs Exp $

=cut

our $VERSION = '1.10';

=head1 SYNOPSIS

	use Parse::IRCLog;

	$result = Parse::IRCLog->parse("perl-2004-02-01.log");

	my %to_print = ( msg => 1, action => 1 );

	for ($result->events) {
		next unless $to_print{ $_->{type} };
		print "$_->{nick}: $_->{text}\n";
	}

=head1 DESCRIPTION

This module provides a simple framework to parse IRC logs in arbitrary formats.

A parser has a set of regular expressions for matching different events that
occur in an IRC log, such as "msg" and "action" events.  Each line in the log
is matched against these rules and a result object, representing the event
stream, is returned.

The rule set, described in greated detail below, can be customized by
subclassing Parse::IRCLog.  In this way, Parse::IRCLog can provide a generic
interface for log analysis across many log formats, including custom formats.

Normally, the C<parse> method is used to create a result set without storing a
parser object, but a parser may be created and reused.

=head1 METHODS

=over

=item C<< new >>

This method constructs a new parser (with C<<$class->construct>>) and
initializes it (with C<<$obj->init>>).  Construction and initialization are
separated for ease of subclassing initialization for future pipe dreams like
guessing what ruleset to use.

=cut

sub new { 
  my $class = shift;
  croak "new is a class method" if ref $class;

  $class->construct->init;
}

=item C<< construct >>

The parser constructor just returns a new, empty parser object.  It should be a
blessed hashref.

=cut

sub construct { bless {} => shift; }

=item C<< init >>

The initialization method configures the object, loading its ruleset.

=cut

sub init {
  my $self = shift;
  $self->{patterns} = $self->patterns;
  $self;
}

=item C<< patterns >>

This method returns a reference to a hash of regular expressions, which are
used to parse the logs.  Only a few, so far, are required by the parser,
although internally a few more are used to break down the task of parsing
lines.

C<action> matches an action; that is, the result of /ME in IRC.  It should
return the following matches:

 $1 - timestamp
 $2 - nick prefix
 $3 - nick
 $4 - the action

C<msg> matches a message; that is, the result of /MSG (or "normal talking") in
IRC.  It should return the following matches:

 $1 - timestamp
 $2 - nick prefix
 $3 - nick
 $3 - channel
 $5 - the action

Read the source for a better idea as to how these regexps break down.  Oh, and
for what it's worth, the default patterns are based on my boring, default irssi
configuration.  Expect more rulesets to be included in future distributions.

=cut

sub patterns {
  return $_[0]{patterns} if ref $_[0] and defined $_[0]{patterns};

  my $p;
  $p->{nick} = qr/([\w\[\]\{\}\(\)^]+)/;

  $p->{chan} = qr/((?:&|#)[\w\[\]\{\}\(\)&#^]*)/;

  $p->{nick_container} = qr/
	<
	  \s*
	  ([%@])?
	  \s*
	  $p->{nick}
	  (?:
			:
			$p->{chan}
	  )?
	  \s*
	>
  /x;

  $p->{timestamp} = qr/\[?(\d\d:\d\d(?::\d\d)?)?\]?/;

  $p->{action_leader} = qr/\*/;

	$p->{msg} = qr/
		$p->{timestamp}
		\s*
		$p->{nick_container}
		\s+
		(.+)
	/x;

	$p->{action} = qr/
		$p->{timestamp}
		\s*
		$p->{action_leader}
		\s+
		([%@])?
		\s*
		$p->{nick}
		\s
		(.+)
	/x;

  $p;
}

=item C<< parse($file) >>

This method parses the file named and returns a Parse::IRCLog::Result object
representing the results.  The C<parse> method can be called on a parser object
or on the class.  If called on the class, a parser will be instantiated for the
method call and discarded when C<parse> returns.

=cut

sub parse {
  my $self = shift;
  $self = $self->new unless ref $self;

	open FILE, shift;

	my @events;
	push @events, $self->parse_line($_) while (<FILE>);
	Parse::IRCLog::Result->new(@events);
}

=item C<< parse_line($line) >>

This method is used internally by C<parse> to turn each line into an event.
While it could someday be made slick, it's adequate for now.  It attempts to
match each line against the required patterns from the C<patterns> result and
if successful returns a hashref describing the event.

If no match can be found, an "unknown" event is returned.

=cut

sub parse_line {
	my ($self, $line) = @_;
	if ($line) {
		return { type => 'msg',    timestamp => $1, nick_prefix => $2, nick => $3, text => $5 }
			if $line =~ $self->patterns->{msg};
		return { type => 'action', timestamp => $1, nick_prefix => $2, nick => $3, text => $4 }
			if $line =~ $self->patterns->{action};
	}
	return { type => 'unknown', text => $line };
}

=back

=head1 TODO

Write a few example subclasses for common log formats.

Add a few more default event types: join, part, nick.  Others?

Possibly make the C<patterns> sub an module, to allow subclassing to override
only one or two patterns.  For example, to use the default C<nick> pattern but
override the C<nick_container> or C<action_leader>.  This sounds like a very
good idea, actually, now that I write it down.

=head1 AUTHORS

Ricardo SIGNES E<lt>rjbs@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Ricardo Signes.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
