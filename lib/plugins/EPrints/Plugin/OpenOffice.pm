package EPrints::Plugin::OpenOffice;

@ISA = ( 'EPrints::Plugin' );

sub check_paths
{
	my( $self ) = @_;

	my $oo_path;

        if( defined $self->{session} )
        {
                # Attempt to read the paths from a local conf file
                $oo_path = $self->{session}->config( 'executables', 'openoffice' );
        }
        else
        {
                $oo_path = EPrints::Config::get( "executables" )->{"openoffice"};
        }

	return 1 if( defined $oo_path && -e $oo_path );

	return 0;
}


sub start
{
	my( $self ) = @_;

	my $oosrv = EPrints::OpenOfficeService->new( session => $self->{session} );

	# couldn't find OpenOffice Service?
	return 0 unless( defined $oosrv );

        my $status = $oosrv->status();

	# Already started?
        return 1 if( $status != 0 );

        if( $oosrv->start() == 1 )
        {
		# Started!
		return 1;
	}

	return 0;
}

sub stop
{
	my( $self ) = @_;

	my $oosrv = EPrints::OpenOfficeService->new( session => $self->{session} );

	# couldn't find OpenOffice Service?
	return 0 unless( defined $oosrv );

        my $status = $oosrv->status();

	# Already stopped?
        return 1 if( $status == 0 );

        if( $oosrv->stop() == 1 )
        {
		# Stopped!
		return 1;
	}

	return 0;
}

sub status
{	
	my $oosrv = EPrints::OpenOfficeService->new( session => $self->{session} );

	# couldn't find OpenOffice Service?
	return -1 unless( defined $oosrv );

	return $oosrv->status();
}

sub get_daemon
{
	my( $self ) = @_;
	
	return EPrints::OpenOfficeService->new( session => $self->{session} );
}

# The actual Service

package EPrints::OpenOfficeService;

use EPrints;

use strict;
no warnings;

my $mainpid;
my $oopid;

sub new
{
	my( $class, %opts ) = @_;

	my $self = bless \%opts, $class;
	
	my $fh;
	if( open( $fh, "+>".$self->logfile() ) )
	{
		$self->{logfile} = $fh;
	}

	# for now, start process as user 'eprints'
	$self->{user} = $self->get_user();

	my @userinfo = getpwnam $self->{user};

	if( !scalar(@userinfo) or !-d $userinfo[7] )
	{
		$self->log( "Error getting user information" );
		return undef;
	}

	$self->{userhome} = $userinfo[7];

	unless( defined $self->{userhome} )
	{
		$self->log( "Error getting user information" );
		return undef;
	}	

	$self->{oo_command} = $self->get_command();
	unless( defined $self->{oo_command} )
	{
		$self->log( "OpenOffice executable not found" );
		return undef;
	}


	return $self;
}

# Attempt to convert '$doc' to '$dir/temp.pdf'
sub convert_to_pdf
{
	my( $self, $doc, $dir ) = @_;

	return unless( $self->is_running() );

	my $session = $doc->get_session;

	my $python = $session->config( "executables", "python" );
	my $uno_converter = $session->config( "executables", "uno_converter" );

	return undef unless( defined $python && defined $uno_converter );
	
	my $python_path = undef;
	if( $uno_converter =~ /^(.*)\/.*$/ )
	{
		$python_path = $1;
	}
	else
	{
		return;
	}
		
	local $ENV{"PYTHONPATH"} = $python_path;
	$ENV{"USER"} = "eprints";
	$ENV{"HOME"} = "/home/eprints";

        my $fn = $doc->get_main;
        my $file = $doc->local_path."/".$fn;
        my $src = $file;
        my $pdf;

	if( $fn =~ /^(.*)\..*$/ )
	{
		$pdf = "$1.pdf";
		$pdf =~ s/[^A-Za-z0-9\.\-\ ]//g;	# sanitise name
		$pdf = "$dir/$pdf";
	}
	else
	{
		$pdf = "$dir/file_conversion.pdf";
	}

        # gives the file a temp name so we know it has no bad characters
        if( $fn =~ m/^(.*)\.([^.]+)$/ )
        {
                $src = $dir.'/'.'temp.'.$2;
                system("cp", $file, $src );
        }

	# will still throw some 'creation of executable memory area failed: Permission denied' errors in the logs but will work
        system( $python, $uno_converter, $src, $pdf);

        unless(-e $pdf)
        {
                $session->log("[ThumbnailMSOffice ERROR] the PDF was not created for docid = ".$doc->get_id);
                return ();
        }

	return $pdf;
}


# returns:
# 	1: stopped ok
# 	0: error
# 	-1: wasn't running
sub stop
{
	my( $self ) = @_;

	if( $self->is_running() )	        
	{
		$self->log( "Stopping OpenOffice" );

		$self->create_suicide_file();

		kill 15, $self->get_pid();
		sleep 1;
		
		if( $self->is_running() )                        
		{
			$self->log( "Failed to stop OpenOffice in a graceful way. Force stopping OpenOffice" );
			kill 9, $self->get_pid();
			sleep 1;
		}
		
		if( $self->is_running() )
		{
			$self->log( "Something is wrong, OpenOffice is still running... Check process with PID=".$self->get_pid());
			return 0;
		}

		$self->remove_pid_file();
	
		$self->log( "OpenOffice process stopped" );

		return 1;
	}
	
	$self->log( "OpenOffice not running" );
	return -1
}

# returns:
# 	1: running
# 	0: not running
# 	-1: stalled?
sub status
{
	my( $self ) = @_;
	if( $self->is_running() )
	{
		# Running ok
		return 1;
	}
	else
	{
		if( $self->get_pid() )
		{
			# Error, stalled?
			return -1;
		}
		else
		{
			# Not running
			return 0
		}
	}
	return 1;
}

# returns:
# 	1: started ok
# 	0: problem starting
# 	-1: already running so not started again
sub start
{
	my( $self ) = @_;
	my $curpid = $self->get_pid();

	if( defined $curpid )
	{
		if( EPrints::Platform::proc_exists( $curpid ) )
		{
			$self->log( "OpenOffice is already running, leaving now." );
			return -1;
		}
		else
		{
			$self->log( "OpenOffice process died. Cleaning the PID file now" );
			$self->remove_suicide_file();
			$self->remove_pid_file();
			if( -e $self->pidfile() )
			{
				$self->log( "Failed to remove OpenOffice PID file. Check at '".$self->pidfile() );
				return 0;
			}
		}
	}

	if( !defined( $mainpid = fork() ) )
	{
		$self->log( "Failed to fork OpenOffice process: $!" );
		return 0;
	}
	elsif( $mainpid == 0 )
	{
		# child process
		while(1)
		{
			if( !defined( $oopid = fork() ) )
			{
				last;
			}
			elsif( $oopid == 0 )
			{
				$self->log( "Starting OpenOffice" );

				$ENV{'USER'} = $self->{user};
				$ENV{'HOME'} = $self->{userhome};

				exec($self->{oo_command});
			}
			else
			{
				# we can restart OO automatically here:
				$self->remove_pid_file();
				$self->write_pid( $oopid );

				# safety net if OO doesn't start/crash at startup
				if( $self->{_starts} )
				{
					$self->{_starts}++;
				}
				else				
				{
					$self->{_starts} = 1;
					$self->{_first_start} = time();
				}

				if( $self->{_starts} > 10 && (time - $self->{_first_start}) < 15 )
				{
					$self->log( "Tried 10 times to start OpenOffice in the last 15 secs. Something is wrong, leaving now" );
					$self->remove_pid_file();
					return 0;
				}

				# waiting for the kid to come back from school:
				waitpid( $oopid, 0 );
				
				if( $self->is_suicide() )
				{
					$self->log( "Suicide file found, leaving now" );
					$self->remove_suicide_file();
					return 1;
				}
				$self->log( "OpenOffice process died, restarting...");
				next;
			}

		}
		return 1;
	}
	else
	{
		# parent process
		return 1;
	}
}

sub pidfile
{
	return EPrints::Config::get( "var_path" )."/openoffice.pid";
}

sub suicidefile
{
	return EPrints::Config::get( "var_path" )."/openoffice.exit";
}

sub logfile
{
	return EPrints::Config::get( "var_path" )."/openoffice.log";
}

sub get_user
{
	return EPrints::Config::get( "user" );
}

sub get_command
{
	my( $self ) = @_;

	my ( $oo_path, $oo_cmd );

	if( defined $self->{session} )
	{
		# Attempt to read the paths from a local conf file
		$oo_path = $self->{session}->config( 'executables', 'openoffice' );
		$oo_cmd = $self->{session}->config( 'invocation', 'openoffice' );
	}
	else
	{
		$oo_path = EPrints::Config::get( "executables" )->{"openoffice"};
		$oo_cmd = EPrints::Config::get( "invocation" )->{"openoffice"};
	}

	return undef unless( defined $oo_path && defined $oo_cmd && (-e $oo_path) );

	$oo_cmd =~ s/\$\(([a-z]*)\)/quotemeta($oo_path)/gei;

	return undef if( $oo_cmd =~ /\$\([a-z]*\)/i );

	return $oo_cmd;
}

sub is_suicide
{
	my( $self ) = @_;
	return -e $self->suicidefile();
}

sub create_suicide_file
{
	my( $self ) = @_;
	unless( open( SF, ">", $self->suicidefile() ) )
	{
		$self->log( "Failed to create the suicide file. This means that the OpenOffice service will not be stopped." );
		return;
	}
        print SF "the end";
        close( SF );
}

sub remove_suicide_file
{
	my( $self ) = @_;
	my $suicidefile = $self->suicidefile();
	return unless( -e $suicidefile );
	my $rm = EPrints::Config::get( "executables" )->{"rm"};
	unless( defined $rm && -e $rm )
	{
		$self->log( "Odd. The program 'rm' is not configured or accessible" );
		return;
	}
	system( "$rm", "$suicidefile" );
}

sub is_running
{
	my( $self ) = @_;
        my $pid = $self->get_pid() or return 0;
        return 1 if kill(0, $pid); # Running as the same uid as us
        return 1 if EPrints::Platform::proc_exists( $pid );
        return 0;
}

sub remove_pid_file
{
	my( $self ) = @_;
	my $pidfile = $self->pidfile();
	return unless( -e $pidfile );
	my $rm = EPrints::Config::get( "executables" )->{"rm"};
	unless( defined $rm && -e $rm )
	{
		$self->log( "Odd. The program 'rm' is not configured or accessible" );
		return;
	}
	system( "$rm", "$pidfile" );
}

sub write_pid
{
	my( $self, $pid ) = @_;
 	my $pidfile = $self->pidfile();
	open( PID, ">", $pidfile) or die "Error writing pid file $pidfile: $!";
        print PID ($pid || $$);
        close( PID );
}

sub get_pid
{
	my( $self ) = @_;
        open( PID, "<", $self->pidfile()) or return undef;
        my $pid;
        while(defined($pid = <PID>))
        {
                chomp($pid);
                last if $pid+0 > 0;
        }
        close( PID );
        return ($pid and $pid > 0) ? $pid : undef;
}

sub log
{
	my( $self, $msg ) = @_;

	my $logfh = $self->{logfile};
	if( defined $logfh )
	{
		print $logfh "$msg\n";
	}
}

sub DESTROY
{
	my( $self ) = @_;

	close( $self->{logfile} ) if( defined $self->{logfile} );
}

1;
