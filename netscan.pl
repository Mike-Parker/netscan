#!/usr/bin/perl
use strict;
use warnings;

our $VERSION = 1.0;

use Net::Ping;
use Net::ARP;
use Net::Netmask;
use Socket;
use Sys::Hostname;
use Config::Simple;
use Time::Piece;
use Getopt::Std;
use autodie qw(open close);
use FindBin;
use Readonly;

use lib $FindBin::Bin;
use netscan qw(build_hosts_hash write_html);

my ($hn, $mac);
my ($host,$rtt,$ip);

my %opts = ();
my %ips  = ();

Readonly my $ADDRS_FIELD => 4;
Readonly my $ECHO_PORT   => 7;

my $time = localtime->datetime;

getopt('c:o:', \%opts);

my $cfg = Config::Simple->new();
$cfg->read($opts{c});

# Determine ports to scan
my @ports = (defined $cfg->param('config.ports') ? $cfg->param('config.ports') : ($ECHO_PORT));

# Determine local IP & MAC addresses
open my $fh, '<', $cfg->param('config.address_file');
my $local_mac = <$fh>;
close $fh;

chomp $local_mac;

my ($local_ip) = inet_ntoa((gethostbyname hostname)[$ADDRS_FIELD]);

# Enumerate CIDR notation into list of addresses
my $block = Net::Netmask-> new($cfg->param('config.cidr'));
my @hosts = $block->enumerate();

# Send SYN packets to all 
my $p = Net::Ping->new('syn');

# Scan ports
foreach my $port (@ports)
{
  $p->{port_num} = $port;

  foreach my $host (@hosts)
  {
    $p->ping($host);
  }
}

# Process ACK responses
while (($host,$rtt,$ip) = $p->ack)
{
  $ips{$ip}++;
}

# Determine associated hostnames and MAC addresses
foreach my $ip (keys %ips)
{
  ($hn) = gethostbyaddr inet_aton($ip), AF_INET;

  $hn = (defined $hn ? $hn : 'UNKNOWN');

  $mac  = uc ($ip eq $local_ip ? $local_mac : Net::ARP::arp_lookup('eth0', $ip));

  $ips{$ip} = [$hn, $mac];
}

my $up_hosts_r = $cfg->param(-block=>'up');

foreach my $ip (keys %ips)
{
  if (defined $cfg->param('down.'.$ip))
  {
    $cfg->delete('down.'.$ip);
    $cfg->param('up.'.$ip, $time);
  }
  elsif (!defined $cfg->param('up.'.$ip))
  {
    $cfg->param('up.'.$ip, $time);
  }

  if (defined $up_hosts_r->{$ip})
  {
    delete $up_hosts_r->{$ip};
  }
}

foreach my $ip (keys %{$up_hosts_r})
{
  $cfg->delete('up.'.$ip);
  $cfg->param('down.'.$ip, $time)
}

my $hosts_r = build_hosts_hash($cfg, \%ips);

# Write changes back to the config file after build_hosts_hash has (potentially?) modified it
$cfg->write();

write_html($hosts_r, $opts{c}, $opts{o});
