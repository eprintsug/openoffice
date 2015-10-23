package EPrints::Plugin::Screen::EPMC::OpenOffice;

use EPrints::Plugin::Screen::EPMC;

@ISA = ( 'EPrints::Plugin::Screen::EPMC' );

use strict;

sub render_messages
{
	my( $self ) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;

	my $frag = $xml->create_document_fragment;

	my $plugin = $repo->plugin( 'OpenOffice' );
	
	unless( defined $plugin )
	{
		$frag->appendChild( $repo->render_message( 'error', $self->html_phrase( 'error:no_plugin' ) ) );
		return $frag;
	}

	unless( $plugin->check_paths() )
	{
		$frag->appendChild( $repo->render_message( 'error', $self->html_phrase( 'error:wrong_paths' ) ) );
		return $frag;
	}

	$frag->appendChild( $repo->render_message( 'message', $self->html_phrase( 'ready' ) ) );

	return $frag;
}

1;
