package EPrints::Plugin::Convert::ImageMagick::ThumbnailMSOffice;

=pod

=head1 NAME

EPrints::Plugin::Convert::ImageMagick::ThumbnailMSOffice

=cut

use strict;
use warnings;

use Carp;

use EPrints::Plugin::Convert;
our @ISA = qw/ EPrints::Plugin::Convert /;

our (%FORMATS, @ORDERED, %FORMATS_PREF);
@ORDERED = %FORMATS = qw(
doc application/msword
ppt application/vnd.ms-powerpoint
pps application/vnd.ms-powerpoint
xls application/vnd.ms-excel
docx application/msword
pptx application/vnd.ms-powerpoint
xlsx application/vnd.ms-excel
);
# formats pref maps mime type to file suffix. Last suffix
# in the list is used.
for(my $i = 0; $i < @ORDERED; $i+=2)
{
	$FORMATS_PREF{$ORDERED[$i+1]} = $ORDERED[$i];
}
our $EXTENSIONS_RE = join '|', keys %FORMATS;



sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "Thumbnail MSOffice Documents";

	unless( EPrints::Utils::require_if_exists('EPrints::OpenOfficeService') )
	{
		$self->{disable} = 1;
		return $self;
	}

	if( defined $self->{session} && $self->{session}->{plugins} )
	{
		my $plugin = $self->{session}->plugin( 'OpenOffice' );
		if( !defined $plugin || $plugin->status != 1 )
		{
			$self->{disable} = 1;
			return $self;
		}
		if( defined $plugin )
		{
			$self->{oosrv} = $plugin->get_daemon;
		}

		if( !defined $self->{oosrv} )
		{
			$self->{disable} = 1;
			return $self;
		}
	}

	$self->{visible} = "all";

	return $self;
}

sub can_convert
{
	my ($plugin, $doc) = @_;
	
	return unless $plugin->get_repository->get_conf( 'executables', 'convert' );

	return unless( defined $plugin->{oosrv} );	

	my %types;

	# Get the main file name
	my $fn = $doc->get_main() or return ();

	if( $fn =~ /\.($EXTENSIONS_RE)$/oi ) 
	{
                $types{"thumbnail_small"} = { plugin => $plugin, };
                $types{"thumbnail_medium"} = { plugin => $plugin, };
                $types{"thumbnail_preview"} = {	plugin => $plugin, };
                $types{"thumbnail_lightbox"} = { plugin => $plugin, };
		$types{"application/pdf"} = { 
                                plugin => $plugin,
                                phraseid => "document_typename_application/pdf",
                                preference => 1,
		};

	}
	return %types;
}

sub export
{
	my ( $plugin, $dir, $doc, $type ) = @_;

	my $pdf = $plugin->{oosrv}->convert_to_pdf( $doc, $dir );

	unless( defined $pdf && -s $pdf )
	{
		$plugin->get_repository()->log("The pdf created for doc ".$doc->get_id()." is a zero byte file an so cannot be converted.");
		return ();
	}

	# conversion to PDF (from e.g. the Uploader):
	if( $type eq 'application/pdf' )
	{
		if( $pdf =~ /^\/.*\/(.*)$/ )
		{
			return $1;
		}

		return ();
	}

        $type =~ m/^thumbnail_(.*)$/;
        my $size = $1;
        return () unless defined $size;

        my $geom = { small=>"66x50", medium=>"200x150",preview=>"400x300", lightbox=>"640x480" }->{$1};

        return () unless defined $geom;

        my @converted_files;
	
	my $convert = $plugin->get_repository->get_conf( 'executables', 'convert' ) or return ();

	my $fn = $size.".png";
	system($convert, "-size","$geom>", $pdf.'[0]', '-resize', "$geom>", $dir . '/' . $fn);
	return () unless( -e "$dir/$fn" );
	EPrints::Utils::chown_for_eprints( "$dir/$fn" );
	push @converted_files, $fn;

        return @converted_files;

}

1;
