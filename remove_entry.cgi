#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 1.0;

use CGI;
use Config::Simple;

use lib '<path_to_dir_containing_netscan.pm>';
use netscan qw(build_hosts_hash write_html);

my $q     = CGI->new;
my @names = $q->param;

my ($cfg_path, $html_path);
my @ips = ();

foreach my $str (@names)
{
    if ($str eq 'cfgPath' && -r $q->param($str))
    {
        $cfg_path = $q->param($str);
    }
    elsif ($str eq 'webPath' && -r $q->param($str))
    {
        $html_path = $q->param($str);
    }    
    elsif ($str =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/osmx)
    {
        push @ips, $str;
    }
}

my $html = <<'END_HTML';
<html>
<body>
END_HTML

if (scalar(@ips) == 0)
{
    $html .= '<p>ERROR: No IP addresses specified for deletion</p>';
}
elsif (!defined $cfg_path)
{
    $html .= '<p>ERROR: No path to configuration file defined</p>';
}
else
{
    my $cfg = Config::Simple->new();
    $cfg->read($cfg_path);
    
    $html .= '<p>';
    
    foreach my $ip (@ips)
    {
        if (defined $cfg->param('ip_to_mac.'.$ip))
        {
            $cfg->delete('ip_to_mac.'.$ip);
            $html .= "Deleted IP '$ip' from [ip_to_mac] section<br>";
        }
        
        if (defined $cfg->param('down.'.$ip))
        {
            $cfg->delete('down.'.$ip);
            $html .= "Deleted IP '$ip' from [down] section<br>";
        }
        
        if (defined $cfg->param('up.'.$ip))
        {
            $cfg->delete('up.'.$ip);
            $html .= "Deleted IP '$ip' from [up] section<br>";
        }
        
        if (defined $cfg->param('ip_to_host.'.$ip))
        {
            $cfg->delete('ip_to_host.'.$ip);
            $html .= "Deleted IP '$ip' from [ip_to_host] section<br>";
        }        
    }
    
    $html .= '</p>';
    $cfg->write();
    
    my $hosts_r = build_hosts_hash($cfg);
    
    write_html($hosts_r, $cfg_path, $html_path);
}

$html .= <<'END_HTML';
<button onclick="history.back()">Back</button>
</body>
</html>
END_HTML

print $html;

