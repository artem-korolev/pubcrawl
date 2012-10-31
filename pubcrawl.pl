#!/usr/bin/env perl
use Mojolicious::Lite;
use strict;
use DateTime;
use Mojo::JSON;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';


my @messages = ();


get '/' => sub {
  my $self = shift;
  my $history = "";
  foreach (@messages) {
     $history .= '[' . $_->{hms} . '] ' . $_->{message} . "\n";
  }
  my @client_ip = $self->req->headers->header('X-Real-IP');
  my $ip =  $client_ip[0];
  my ($info, $lon,$lat) = visitor_info($ip );
  my $lon_diff = 0.01;
  my $lat_diff = 0.01;
  $self->stash(history => $history, visitor_info => $info,
               lon1=>$lon-$lon_diff,lon2=>$lon+$lon_diff,
               lat1=>$lat-$lat_diff, lat2=>$lat+$lat_diff);
  $self->render('index');
};


post '/chat' => sub {
   my $self = shift;
   
   # send to comet server
   use Realplexor;
   my $dt = DateTime->now( time_zone => 'Europe/Tallinn');
   my $rpl = new Realplexor ({
    host => "127.0.0.1", # host at which Realplexor listens for incoming data
    port=> "10010",     # incoming port (see IN_ADDR in dklab_realplexor.conf)
    #namespace => "frontpage_chat"      # namespace to use (optional)
   });
   $rpl->send("chat", {hms  => $dt->hms, message => $self->param('message')});
   $self->render('empty');
   
   # save in history
   unshift @messages, {hms  => $dt->hms, message => $self->param('message')};
   my $inf_loop_stop = 0;
   while ($#messages > 20) {
      pop @messages;
      break if $inf_loop_stop++>10; 
   }
};


sub visitor_info {
   use Geo::IP::PurePerl;
 my $ip = shift;
 use Data::Dumper;
 warn Dumper $ip->[0];
my $gi = Geo::IP::PurePerl->open("GeoIPCity.dat", GEOIP_STANDARD);
my $addr = $ip;
my $record = $gi->get_city_record_as_hash($addr->[0]);
return ("country_code:\t" . $record->{country_code} . "<br>".
        "country_code3:\t" . $record->{country_code3} . "<br>".
        "country_name:\t" . $record->{country_name} . "<br>".
        "region:\t\t" . $record->{region} . "<br>".
        "city:\t\t" . $record->{city} . "<br>".
        "postal code:\t" . $record->{postal_code} . "<br>".
        "latitude:\t" . $record->{latitude} . "<br>".
        "longitude:\t" . $record->{longitude} . "<br>".
        "metro code:\t" . $record->{metro_code} . "<br>".
        "area code:\t" . $record->{area_code} . "<br>", $record->{longitude},$record->{latitude});

}
############# NORMAL FUNCTION WITH REAL GEO::IP SUPPORT.. but it fuck need stupid geoip c lib, that fuck does not compiles in windows.. SUUUXXXX!!!!
#sub visitor_info {
#   use Geo::IP;
# my $ip = shift;
# use Data::Dumper;
# warn Dumper $ip->[0];
#my $gi = Geo::IP->open("./GeoCity.dat", GEOIP_STANDARD);
#my $addr = $ip;
#my $record = $gi->record_by_addr($addr->[0]);
#return ("country_code:\t" . $record->country_code . "<br>".
#        "country_code3:\t" . $record->country_code3 . "<br>".
#        "country_name:\t" . $record->country_name . "<br>".
#        "region:\t\t" . $record->region . "<br>".
#        "city:\t\t" . $record->city . "<br>".
#        "postal code:\t" . $record->postal_code . "<br>".
#        "latitude:\t" . $record->latitude . "<br>".
#        "longitude:\t" . $record->longitude . "<br>".
#        "metro code:\t" . $record->metro_code . "<br>".
#        "area code:\t" . $record->area_code . "<br>", $record->longitude,$record->latitude);
#
#}



# Change scheme if "X-Forwarded-Protocol" header is set to "https"
app->hook(before_dispatch => sub {
          my $self = shift;
          $self->req->url->base->scheme('https')
          if $self->req->headers->header('X-Forwarded-Protocol') eq 'https';
});

app->start;
