
$c->{executables}->{openoffice} = '/opt/openoffice.org3/program/soffice.bin';
$c->{executables}->{python} = '/opt/openoffice.org3/program/python';
$c->{executables}->{uno_converter} = "$c->{base_path}/bin/DocumentConverter.py";

$c->{invocation}->{openoffice} = '$(openoffice) "-accept=socket,host=localhost,port=8100;urp;StarOffice.ServiceManager" -norestore -nofirststartwizard -nologo -headless';
