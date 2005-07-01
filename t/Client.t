#!/usr/bin/perl -w

use strict;
use Test::More tests => 11;
use lib './lib';

  my $cmd = 'PERL5LIB=./lib perl -MBusiness::Bof::Server::CLI -e run -- -c t/bof.xml';
  defined( my $pid = fork) or die "fork: $!";
  exec $cmd unless $pid;
  sleep 10;

BEGIN { use_ok('Business::Bof::Client'); };

  my $fw = Business::Bof::Client->new({
    server  => 'localhost',
    port    => 25190,
    session => 'bofserver'
  });

  ok(defined $fw, 'Defined Client Object');
  ok($fw->isa('Business::Bof::Client'), 'Object is right type?');
  my $session_id = $fw->login({name=>'bof',password=>'test'});
  ok($session_id, 'Login');

  my ($client_data, $cache_data, $cm_data);
  ok($client_data = $fw->get_clientdata(), 'Get clientdata');

  is($fw->cache_data('bof', $client_data), undef, 'Cache clientdata');
  ok($cache_data = $fw->get_cachedata('bof'), 'Get cached data');
  ok(eq_hash($client_data, $cache_data), 'Compare cached data');

  my $parms = {
    class => '__test__',
    data => 'test',
    method => 'test',
  };
  ok($cm_data = $fw->call_method($parms), 'Call method');
  is($cm_data, 'Test', 'Call method result');

  is($fw->logout(),0, 'Logout');

  kill 'INT', $pid;
