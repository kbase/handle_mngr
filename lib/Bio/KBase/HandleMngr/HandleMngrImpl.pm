package Bio::KBase::HandleMngr::HandleMngrImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

HandleMngr

=head1 DESCRIPTION

The HandleMngr module provides an interface for the workspace
service to make handles sharable. When the owner shares a
workspace object that contains Handles, the underlying shock
object is made readable to the person that the workspace object
is being shared with.

=cut

#BEGIN_HEADER
use HTTP::Request ;
use LWP::UserAgent;
use JSON;

use Data::Dumper;
use strict;
use warnings;

use Bio::KBase::HandleMngrConstants 'adminToken';
use Bio::KBase::HandleService;

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR

    our $cfg = {};

    if (defined $ENV{KB_DEPLOYMENT_CONFIG} && -e $ENV{KB_DEPLOYMENT_CONFIG}) {
	$cfg = new Config::Simple($ENV{KB_DEPLOYMENT_CONFIG}) or
	    die "Can not create Config object";
	print STDERR "Using $ENV{KB_DEPLOYMENT_CONFIG} for configs\n";
    }
    else{
	print STDERR "Can't find config.\n" ;
    }

    my $login    = $cfg->param('HandleMngr.admin-login')    || undef;
    my $password = $cfg->param('HandleMngr.admin-password') || undef;


    if ($login){
	print STDERR "Creating admin token\n" ;
	my $msg       = `kbase-login $login -p $password`;
	my $lcfg_file = $ENV{HOME}."/.kbase_config" ;

	print STDERR $msg , "\n";

	unless(-f $lcfg_file){
	    print STDERR "Can't find file $lcfg_file\n";
	    exit;
	}

	my $lcfg = new Config::Simple( filename=> $lcfg_file ,
				       syntax=>'ini') or die "can not create Config object";
	
	
	$self->{'admin-token'} = $lcfg->param('authentication.token');
	
	$msg = `kbase-logout` ;
    }
    else{
	print STDERR "No admin user found.\n" ;
    }


    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 is_readable

  $return = $obj->is_readable($token, $nodeurl)

=over 4

=item Parameter and return types

=begin html

<pre>
$token is a string
$nodeurl is a string
$return is an int

</pre>

=end html

=begin text

$token is a string
$nodeurl is a string
$return is an int


=end text



=item Description

The is_readable function will return true if the
underlying shock object is readable by the owner of the
token. The token is passed by the client.

=back

=cut

sub is_readable
{
    my $self = shift;
    my($token, $nodeurl) = @_;

    my @_bad_arguments;
    (!ref($token)) or push(@_bad_arguments, "Invalid type for argument \"token\" (value was \"$token\")");
    (!ref($nodeurl)) or push(@_bad_arguments, "Invalid type for argument \"nodeurl\" (value was \"$nodeurl\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to is_readable:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'is_readable');
    }

    my $ctx = $Bio::KBase::HandleMngr::Service::CallContext;
    my($return);
    #BEGIN is_readable

	print Dumper $ctx;
	my $ua = LWP::UserAgent->new();
	my $req = new HTTP::Request("GET",$nodeurl,HTTP::Headers->new('Authorization' => "OAuth $token"));
    $ua->prepare_request($req);
    my $get = $ua->send_request($req);
    if ($get->is_success) {
        $return = 1;
	print STDERR "MSG (is_readable): " .  $get->content , "\n";
    }
    else{
	$return = 0;
    }
    #END is_readable
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to is_readable:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'is_readable');
    }
    return($return);
}




=head2 add_read_acl

  $return = $obj->add_read_acl($wstoken, $hids, $username)

=over 4

=item Parameter and return types

=begin html

<pre>
$wstoken is a string
$hids is a reference to a list where each element is a HandleId
$username is a string
$return is an int
HandleId is a string

</pre>

=end html

=begin text

$wstoken is a string
$hids is a reference to a list where each element is a HandleId
$username is a string
$return is an int
HandleId is a string


=end text



=item Description



=back

=cut

sub add_read_acl
{
    my $self = shift;
    my($wstoken, $hids, $username) = @_;

    my @_bad_arguments;
    (!ref($wstoken)) or push(@_bad_arguments, "Invalid type for argument \"wstoken\" (value was \"$wstoken\")");
    (ref($hids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"hids\" (value was \"$hids\")");
    (!ref($username)) or push(@_bad_arguments, "Invalid type for argument \"username\" (value was \"$username\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to add_read_acl:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_read_acl');
    }

    my $ctx = $Bio::KBase::HandleMngr::Service::CallContext;
    my($return);
    #BEGIN add_read_acl

	$return = 0;
	my $admin_token = adminToken;
	my @handles = ();

	# given a list of handle ids, get the handles
	my $client = Bio::KBase::HandleService->new();
	# @handles = $client->hids_to_handles($hids);

	# given a list of handles, update the acl of handle->{id}

	# is the person identified by $wstoken the owner of the
	# node referenced by $handle. We're not going to update
	# any nodes unless $wstoken owns al the handles.

	# TODO get userid from token
	my $userid = '';

	foreach my $handle (@handles) {
		# TODO if not owner then die, die, die!
	}

	# if we make it this far, then wstoken owns all the nodes
	foreach my $handle (@handles) {

		my $nodeurl = $handle->{url} . '/' . $handle->{id};
		my $ua = LWP::UserAgent->new();

		my $header = HTTP::Headers->new('Authorization' => "OAuth " . $admin_token  ) ;
		print STDERR Dumper $header ;

		my $req = new HTTP::Request("PUT",$nodeurl."/acl/read?users=$userid",HTTP::Headers->new('Authorization' => "OAuth " . $self->{'admin-token'}  ));
		$ua->prepare_request($req);
		my $put = $ua->send_request($req);
		if ($put->is_success) {
			$return += 1;
			print STDERR "Success: " . $put->message , "\n" ;
			print STDERR "Success: " . $put->content , "\n";
		}
		else {
			print STDERR "Error: " . $put->message , "\n" ;
			print STDERR "Error: " . $put->content , "\n";
		}
	}


    #END add_read_acl
    my @_bad_returns;
    (!ref($return)) or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to add_read_acl:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_read_acl');
    }
    return($return);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 HandleId

=over 4



=item Description

The add_read_acl functions will update the acl of the shock
node that the handle references if the owner of the token
is the owner of the underlying shock node. The underlying
shock node will be made readable to the user requested.


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=cut

1;
