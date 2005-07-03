use Module::Build;
my $build = Module::Build->new (
  module_name => 'Business::Bof::Client',
  dist_name => 'Business::Bof::Client',
  dist_author => 'Kaare Rasmussen <kar at kakidata.dk>',
  dist_abstract => 'Application Server featuring User Control and Remote Object Execution',
  license => 'perl',
  requires => {
    'POE'                          => '0.29',
    'SOAP::Lite'                   => '0.60',
    'LWP::Protocol::https'         => '0'
  },
);
$build->create_build_script;
