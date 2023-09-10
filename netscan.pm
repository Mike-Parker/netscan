package netscan;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(build_hosts_hash write_html);

use Time::Piece;

our $VERSION = 1.0;

sub write_html
{
    my ($hosts_r, $cfg_path, $html_path) = @_;
    
    my $time = localtime->datetime;
    
    my @sorted_hosts = map {sprintf '%d.%d.%d.%d', split /[.]/osmx}
                       sort
                       map {sprintf '%03d.%03d.%03d.%03d', split /[.]/osmx}
                       keys %{$hosts_r};
    
    my $html = <<'END_HEADER';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html lang='en-GB'>
  <head>
    <meta http-equiv="refresh" content="300">
    <title>Netscan Results</title>
    <style type='text/css'>
      table {font-family: monaco, Consolas, "Lucida Console", monospace; font-size: 12px; }
      table { border-collapse: collapse; }
      table.center { margin-left:auto; margin-right:auto; }
      table, th, td { border: 1px solid black; }
      th, td { padding: 10px; }
      .red { color: red; }
      .green { color: green ;}
    </style>
  </head>
  <body>
    <br>
    <form action="/cgi-bin/remove_entry.cgi" method="post">
END_HEADER

    $html .= '    <input type="hidden" name="cfgPath" value="'.$cfg_path.'">'."\n";
    $html .= '    <input type="hidden" name="webPath" value="'.$html_path.'">'."\n";

    $html .= <<'END_TABLE_HEADER';
    <table class="center" summary="" border="1">
      <tr>
        <th style="font-size: 16px">&#128465;</th><th>Hostname</th><th>IP Address</th><th>MAC Address</th><th>Status</th><th>Since</th>
      </tr>
END_TABLE_HEADER

    foreach my $ip (@sorted_hosts)
    {
        my $color = ($hosts_r->{$ip}->[0] eq 'UP' ? 'green' : 'red');

        $html .= "      <tr class='$color'>\n";
        $html .= '        <td><input name="'.$ip.'" type="checkbox"></td><td align="right">'.$hosts_r->{$ip}->[1].'</td><td>'.$ip.'</td><td>'.$hosts_r->{$ip}->[2].'</td><td align="center">'.$hosts_r->{$ip}->[0].'</td><td>'.$hosts_r->{$ip}->[3]."</td>\n";
        $html .= "      </tr>\n";
    }

    $html .= "      <tr>\n";
    $html .= '        <td colspan="6">'."\n";
    $html .= '          <div style="float:left;text-align:left;width:50%;"><input type="submit" value="Update"></div>'."\n";
    $html .= '          <div style="float:right;text-align:right;width:50%;">Last updated: '.$time.'</div>'."\n";
    $html .= "        </td>\n";

    $html .= <<'END_FOOTER';
      </tr>
    </table>
    </form>
  </body>
</html>
END_FOOTER

    open my $fh, '>', $html_path or croak('Can\'t open output file '.$html_path);
    print $fh $html;
    close $fh or croak('Can\'t close output file '.$html_path);
    
    return;
}

sub build_hosts_hash
{
    my ($cfg, $ips_r) = @_;
    
    my %hosts = ();
    my ($hn, $mac);
    
    foreach my $ip (keys %{$cfg->param(-block=>'down')})
    {
        $hn  = (defined $cfg->param('ip_to_host.'.$ip) ? $cfg->param('ip_to_host.'.$ip) : 'UNKNOWN');
        $mac = (defined $cfg->param('ip_to_mac.'.$ip)  ? $cfg->param('ip_to_mac.'.$ip)  : 'UNKNOWN');
        
        $hosts{$ip} = ['DOWN', $hn, $mac, $cfg->param('down.'.$ip)];
    }
    
    foreach my $ip (keys %{$cfg->param(-block=>'up')})
    {
        if (defined $ips_r)
        {
              ($hn, $mac) = @{$ips_r->{$ip}};
              
              $cfg->param('ip_to_host.'.$ip, $hn);
              $cfg->param('ip_to_mac.'.$ip, $mac);
        }
        else
        {
            $hn  = (defined $cfg->param('ip_to_host.'.$ip) ? $cfg->param('ip_to_host.'.$ip) : 'UNKNOWN');
            $mac = (defined $cfg->param('ip_to_mac.'.$ip)  ? $cfg->param('ip_to_mac.'.$ip)  : 'UNKNOWN');
        }
        
        $hosts{$ip} = ['UP', $hn, $mac, $cfg->param('up.'.$ip)];
    }
    
    return \%hosts;
}

1;