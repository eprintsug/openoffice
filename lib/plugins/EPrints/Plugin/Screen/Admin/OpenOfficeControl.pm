package EPrints::Plugin::Screen::Admin::OpenOfficeControl;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);
	
	$self->{actions} = [qw/ start stop /]; 

	$self->{appears} = [
		{ 
			place => "admin_actions_system", 	
			action => "start",
			position => 1200, 
		},
		{ 
			place => "admin_actions_system", 	
			action => "stop",
			position => 1200, 
		},
	];

	if( defined $self->{session} && defined $self->{session}->{plugins} )
	{
		$self->{oo_plugin} = $self->{session}->plugin( 'OpenOffice' );
	}

	return $self;
}

sub about_to_render
{
	my( $self ) = @_;
	$self->{processor}->{screenid} = "Admin";
}

sub allow_stop
{
	my( $self ) = @_;

	return 0 if( !defined $self->{oo_plugin} || $self->{oo_plugin}->status() == 0 ); 
	# re-using indexer's permissions
	return $self->allow( "indexer/stop" );
}

sub action_stop
{
	my( $self ) = @_;

	my $result = ( defined $self->{oo_plugin} ) ? $self->{oo_plugin}->stop() : 0;

	if( $result == 1 )
	{
		$self->{processor}->add_message( 
			"message", 
			$self->html_phrase( "openoffice_stopped" ) 
		);
	}
	else
	{
		$self->{processor}->add_message( 
			"error", 
			$self->html_phrase( "cant_stop_openoffice" ) 
		);
	}
}

sub allow_start
{
	my( $self ) = @_;

	return 0 if( !defined $self->{oo_plugin} );

	my $status = $self->{oo_plugin}->status;

	if( $status == 0 )
	{
		return $self->allow( "indexer/start" );
	}

	return 0;
}

sub action_start
{
	my( $self ) = @_;
	
	my $result = ( defined $self->{oo_plugin} ) ? $self->{oo_plugin}->start() : 0;

	if( $result == 1 )
	{
		$self->{processor}->add_message( 
			"message", 
			$self->html_phrase( "openoffice_started" ) 
		);
	}
	else
	{
		$self->{processor}->add_message( 
			"error", 
			$self->html_phrase( "cant_start_openoffice" )
		);
	}
}

1;
