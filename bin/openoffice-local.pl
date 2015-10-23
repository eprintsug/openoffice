#!/usr/bin/perl -w

use strict;

use FindBin;
use lib "$FindBin::Bin/../../../perl_lib";

use EPrints;

$|=1;

if( scalar( @ARGV ) != 2 )
{
        print "\nUsage is:";
        print "\n\topenoffice-local.pl repository_id {start,stop}\n";
        exit(1);
}

my $session = new EPrints::Session( 1, $ARGV[0] ) or die( "No repository '$ARGV[0]'" );

my $cmd = $ARGV[1];

die( "Wrong command 'ARGV[1]'" ) unless( defined $cmd && $cmd =~ /^(start|stop)$/ );

my $plugin = $session->plugin( 'OpenOffice' ) or die( 'no Plugin::OpenOffice plugin found' ); 

if( $cmd eq 'start' )
{
	if( $plugin->start() )
	{
		print "OpenOffice started\n";
	}
	else
	{
		print "Failed to start OpenOffice\n";
	}
}
elsif( $cmd eq 'stop' )
{
	if( $plugin->stop() )
	{
		print "OpenOffice stopped\n";
	}
	else
	{
		print "Failed to stop OpenOffice\n";
	}
}

$session->terminate;
exit;
