package Business::Bof::Client;

use warnings;
use strict;
use Scalar::Util qw(blessed refaddr);
use SOAP::Lite;

our $VERSION = 0.06;

sub new {
  my ($type, $params) = @_;
  my $self = {};
  my $protocol = $params->{ssl} ? 'https' : 'http';
  my $uri = "$protocol://$params->{server}:$params->{port}/";
  my $proxy = "$uri\?session=$params->{session}";
  my $remote = SOAP::Lite -> uri($uri) -> proxy($proxy);
  die("Couldn't connect to server $uri") unless $remote;
  $self->{remote} = $remote;
  my $class = bless $self,$type;
  my $res = $class->setup_class('Business::Bof::Server::Connection');
  _setup_methods();
  return $class;
}

sub _setup_methods {
  no strict qw/refs/;
  foreach my $meth (qw/get_clientdata get_data cache_data get_cachedata get_task
    get_tasklist print_file get_printfile get_printfilelist get_queuelist call_method/) {
    *{__PACKAGE__."::${meth}"} = sub {
      my $self = shift;
      &{"Business::Bof::Server::Connection::${meth}"}($self->{session_id}, @_);
    };
  }
}

sub disconnect {
  my $self = shift;
  my $remote = $self->{remote};
  $remote->disconnect;
}

sub login {
  my ($self, $log_info) = @_;
  my $session_id = Business::Bof::Server::Connection::login($log_info);
  $self->{session_id} = $session_id;
  $self->{SOAPsessionId} = SOAP::Data->name(sessionId => $session_id);
  return $session_id;
}

sub logout {
  my $self = shift;
  my $session_id = $self->{session_id};
  Business::Bof::Server::Connection::logout($session_id);
}

sub set_sessionid {
  my ($self, $session_id) = @_;
  $self->{session_id} = $session_id;
  $self->{SOAPsessionId} = SOAP::Data->name(sessionId => $session_id);
}

sub setup_class {
  my ($self, $class, @package) = @_;
  my $methods = $self->_get_allowed_methods($class, @package);
  $self->_setup_class($class, %$methods);
}

sub _get_allowed_methods {
  my ($self, $class, @package) = @_;
  my $remote = $self->{remote};
  my $session_id = SOAP::Data->name(sessionId => $self->{SOAPsessionId});
  my $data = {class => $class, package => \@package};
  my $SOAPparms = SOAP::Data->name(data => $data);
  my $res = $remote->setupClass($session_id,$SOAPparms)->result;
  return $res;
}

sub _setup_class {
  my ($self, $class, %methods) = @_;
  my $file = $class;
  $file =~ s/\:\:/\//g;
  $INC{"${file}.pm"} = '**Bof**';
  no strict qw/refs/;
  foreach my $pkg (keys %methods) {
    foreach my $meth (keys %{ $methods{$pkg} }) {
      *{"${pkg}::${meth}"} = sub { $self->_soap_dispatch($pkg, $meth, @_) if $self; };
    }
  }
}

sub _soap_dispatch {
  my ($self, $class, $meth, @parms) =  @_;
  my $obj = shift(@parms) if blessed($parms[0]);
  unshift(@parms, $obj->{obj}) if defined($obj);
  my $remote = $self->{remote};
  return if !$self->{remote};
  my $session_id = SOAP::Data->name(sessionId => $self->{SOAPsessionId});
  my $method = SOAP::Data->name(method => {class => $class, method => $meth});
  my $SOAPparms = SOAP::Data->name(parms => \@parms);
  my $res = $remote->execMethod($session_id,$method,$SOAPparms)->result;
  object_proxy($res);
  return undef if $#$res == -1;
  $res = shift @$res if !$#$res;
  return wantarray && ref($res) eq 'ARRAY' ? @$res : $res;
}

sub object_proxy {
  foreach my $elm (@{ $_[0] }) {
    if (ref($elm) eq 'ARRAY' && ${$elm}[0] =~ /__bof__/) {
      my $h = {obj => $elm};
      my $cl = ${$elm}[1];
      bless $h, $cl;
      $elm = $h;
    }
  }
}

1;
__END__

=head1 NAME

Business::Bof::Client -- Client interface to Business Oriented Framework

=head1 SYNOPSIS

OBSOLETE!!
  use Business::Bof::Client;

  my $client = new Business::Bof::Client(server => localhost,
        port => 12345,
        session => myserver
  );
  my $session_id = $client->login({
    name => $username,
    password => $password
  });

  my $parms = {
    '!Table' => 'order, customer',
    '!TabJoin' => 'order JOIN customer USING (contact_id)',
    '$where'  =>  'ordernr = ?',
    '$values'  =>  [ $ordernr ]
  };

  $result = $client -> getData($parms);
  $showresult = Dumper($result);
  print "getData: $showresult\n";
OBSOLETE!!

=head1 DESCRIPTION

Business::Bof::Client is a Perl interface to the Business Oriented
Framework Server. It is meant to ease the pain of accessing the server,
making SOAP programming unnecessary.

=head2 Method calls

=over 4

=item $obj = new(server => $hostname, port => $portnr, session => $session)

Instantiates a new client and performs a connection to the server with
the information given. Will fail if no server is active at that address.

=item $session_id = $obj -> login({name => $username, password => $password});

Creates a session in the server and returns an ID. This ID is for the
pleasure of the user only.

I<name> and I<password> must be a valid pair in the Framework Database.

=item $obj -> logout()

Will terminate the session in the server and delete all working data.

=item $obj->setup_class($class);

Will expose the $class to the client program. Methods from this class will
be executed on the server.
... more

=item $obj -> get_clientdata()

Returns a hash ref with 

a) The data provided in the configuration file under the section
C<ClientSettings>.

b) Some data from the current session to be used by the client.

=item $obj -> get_data($parms);

The purpose of getData is to request a set of data from the server. The
format of the request is the same as is used by DBIx::Recordset. E.g.:

  my $parms = {
    '!Table' => 'order, customer',
    '!TabJoin' => 'order JOIN customer USING (contact_id)',
    '$where'  =>  'ordernr = ?',
    '$values'  =>  [ $ordernr ]
  };

=item $obj -> set_sessionid($session_id)

Remind Business::Bof::Client of which session_id it should use.

set_sessionid, cache_Data and get_cachedata are all primarily meant for 
stateless environments, id. web development.

=item $obj -> cache_data($cachename, $somedata);

cacheData will let the server save some data for the client. It is
very useful in a web environment, where the client is stateless. E.g.:

my $data = {
  foo => 'bar',
  this => 'that'
};
$obj -> cache_data('some data', $data);

=item $obj -> get_cachedata($cachename);

get_cachedata retrieves the cached data, given the right key. E.g.:

$thedata = $obj -> get_cachedata('some data');

=item $obj -> get_task($session_id, $taskId);

The server returns the task with the given taskId.

=item $obj -> get_tasklist($session_id);

The server returns the list of tasks.

=item $obj -> print_file

print_file will print a file from Bof's queue system. The given parameter
indicates which file is to be printed.

It looks like this:

C<< $parms = {
  type => 'doc' or 'print', 
  file => $filename,
  queue => $queuename
}; >>

=item $obj -> get_printfile

get_printfile works like printFile, exept it returns the file instead of
printing it.

=item $obj -> get_printfilelist

get_printfilelist returns an array containing information about the files
in the chosen queue

C<< $parms = {
  type => 'doc' or 'print', 
  queue => $queuename
}; >>

=item $obj -> getQueuelist

get_queuelist returns an array containing information about the available
queues.

C<< $parms = {
  type => 'doc' or 'print', 
}; >>


=item $obj -> call_method

The main portion of the client call will be callMethod. It will find the
class and method, produce a new instant and execute it with the given
data as parameter.

It looks like this:

$parms = {
  class => 'myClass',
  data => $data,
  method => 'myMethod',
  [long => 1,
  task => 1 ]
};

$res = $obj -> call_method($parms);
 
Two modifiers will help the server determine what to do with the call.

If C<long> is defined, the server will handle it as a long running task,
spawning a separate process.

If C<task> is defined, the server will not execute the task immediately,
but rather save it in the framework's task table. The server will
execute it later depending on the server's configuration settings.

=back

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>
