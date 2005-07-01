package __test__;

use strict;

sub new {
  my ($type, $db, $serverSettings) = @_;
  my $self = {};
  $self->{db} = $db;
  $self->{domdir} = $serverSettings->{domdir};
  return bless $self,$type;
}

sub test {
  my $self = shift;
  return "Test";
}

1;
