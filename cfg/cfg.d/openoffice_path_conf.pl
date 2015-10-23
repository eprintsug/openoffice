
# Bazaar Configuration

$c->{plugins}{"OpenOffice"}{params}{disable} = 0;
$c->{plugins}{"Screen::Admin::OpenOfficeControl"}{params}{disable} = 0;
$c->{plugins}{"Screen::EPMC::OpenOffice"}{params}{disable} = 0;
$c->{plugins}{"Convert::ImageMagick::ThumbnailMSOffice"}{params}{disable} = 0;

# OpenOffice paths (should rather be defined in the global file under lib/syscfg.d/openoffice.pl)
 
# $c->{executables}->{openoffice} = '/opt/openoffice.org3/program/soffice.bin';
# $c->{executables}->{python} = '/opt/openoffice.org3/program/python';
# $c->{invocation}->{openoffice} = '$(openoffice) "-accept=socket,host=localhost,port=8100;urp;StarOffice.ServiceManager" -norestore -nofirststartwizard -nologo -headless';

$c->{executables}->{uno_converter} = "$c->{archiveroot}/bin/DocumentConverter.py";

