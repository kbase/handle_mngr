package Bio::KBase::HandleMngr::HandleMngrImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.2.0";
our $GIT_URL = "https://github.com/kkellerlbl/handle_mngr";
our $GIT_COMMIT_HASH = "ce13d245839b54a7db48b3befd5ce0f47d07757b";

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

use Bio::KBase::AuthToken;
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
	else {
		print STDERR "Can't find config.\n" ;
	}

	my $login = $cfg->param('HandleMngr.admin-login');
	if (ref $login eq 'ARRAY') {
		$login = undef;
	}
	my $password = $cfg->param('HandleMngr.admin-password');
	if (ref $password eq 'ARRAY') {
		$password = undef;
	}

	my $token = $cfg->param('HandleMngr.admin-token');
	if (ref $token eq 'ARRAY') {
		$token = undef;
	}
	
	$self->{handle_url} = $cfg->param('HandleMngr.handle-service-url');
	if (ref $self->{handle_url} eq 'ARRAY') {
		$self->{handle_url} = undef
	}
        unless ($self->{handle_url}) {
            die 'no handle-service-url supplied, can not continue';
        }           
	
	$self->{auth_svc} = $cfg->param('HandleMngr.auth-service-url');
	if (ref $self->{auth_svc} eq 'ARRAY') {
		$self->{auth_svc} = undef
	}
        unless ($self->{auth_svc}) {
            $self->{auth_svc} = $Bio::KBase::Auth::AuthorizePathDefault;
            warn 'no auth-service-url supplied, using default';
        }
        warn 'using auth-service-url ' . $self->{auth_svc};
	
	my $allowed_users = $cfg->param('HandleMngr.allowed-users');
	if (ref $allowed_users eq 'ARRAY') {
		my @allowed_users_filtered = grep defined, @$allowed_users;
		$self->{allowed_users} = \@allowed_users_filtered;
	} else {
		$self->{allowed_users} = [$allowed_users];
	}
	warn "Allowed users: [" . join(" ", @{$self->{allowed_users}}) . ']';
		
	my $authtoken;
        
        # the number of simultaneous requests may be overloading the current
        # auth service.  Occasionally I see read timeouts with the
        # default AuthToken LWP timeout (10s).  There's no point in
        # fixing the current auth service, so as a stopgap measure,
        # try to spread out the requests so they're less likely to
        # timeout.  When the new auth service is ready we should remove
        # this sleep and make sure it performs okay (and if not, perhaps
        # the issue is in the client libs)
	# auth2 is now in place in production, so commenting out this sleep
	# sleep(int(rand(15)));

	if ($token) {
        	warn 'Creating admin token from supplied token';
		$authtoken = Bio::KBase::AuthToken->new(
                    auth_svc=>$self->{'auth_svc'}, ignore_authrc=>1, token => $token);
		if (!$authtoken->validate()) {
			die "Login with admin token failed: " . $authtoken->error_message;
		}
	} elsif ($login and $password) {
        	warn 'Creating admin token from username and password';
		$authtoken = Bio::KBase::AuthToken->new(
		    auth_svc=>$self->{'auth_svc'}, ignore_authrc=>1, user_id => $login, password => $password);
	} else {
            die 'No token or id/pw supplied, can not continue';
        }

	if (!defined($authtoken->token())) {
                warn 'received an error from auth: ' . $authtoken->{'error_message'};
		die "Login as $login failed in pid $$";
	} else {
		$self->{'admin-token'} = $authtoken->token();
	}

        warn "HandleMngr at pid $$ ready for queries";

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

    my $ctx = $Bio::KBase::HandleMngr::HandleMngrServer::CallContext;
    my($return);
    #BEGIN is_readable

#	print Dumper $ctx;
    if ($nodeurl)
    {
        my $ua = LWP::UserAgent->new();
        my $req = new HTTP::Request("GET",$nodeurl);
        $req = new HTTP::Request("GET",$nodeurl,HTTP::Headers->new('Authorization' => "OAuth $token")) if ($token);
        $ua->prepare_request($req);
        my $get = $ua->send_request($req);
        if ($get->is_success) {
            $return = 1;
            #warn "MSG (is_readable): " .  $get->content;
        }
        else{
	    $return = 0;
        }
    } else
    {
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

  $obj->add_read_acl($hids, $username)

=over 4

=item Parameter and return types

=begin html

<pre>
$hids is a reference to a list where each element is a HandleMngr.HandleId
$username is a string
HandleId is a string

</pre>

=end html

=begin text

$hids is a reference to a list where each element is a HandleMngr.HandleId
$username is a string
HandleId is a string


=end text



=item Description

The add_read_acl function will update the acl of the shock
node that the handle references. The function is only accessible to a 
specific list of users specified at startup time. The underlying
shock node will be made readable to the user requested.

=back

=cut

sub add_read_acl
{
    my $self = shift;
    my($hids, $username) = @_;

    my @_bad_arguments;
    (ref($hids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"hids\" (value was \"$hids\")");
    (!ref($username)) or push(@_bad_arguments, "Invalid type for argument \"username\" (value was \"$username\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to add_read_acl:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'add_read_acl');
    }

    my $ctx = $Bio::KBase::HandleMngr::HandleMngrServer::CallContext;
    #BEGIN add_read_acl

	my $has_user = 0;
	foreach my $user (@{$self->{allowed_users}}) {
		if ($user eq $ctx->{user_id}) {
			$has_user = 1;
			last;
		}
	}
	if (!$has_user) {
		die "User $ctx->{user_id} may not run the add_read_acl method"
	}
	

	my $client;
	# given a list of handle ids, get the handles
	if ($self->{handle_url}) {
		$client = Bio::KBase::HandleService->new($self->{handle_url});
	} else {
		$client = Bio::KBase::HandleService->new();
	}
	my $handles = $client->hids_to_handles($hids);

	
	# given a list of handles, update the acl of handle->{id}
	my $admin_token = $self->{'admin-token'};
	my %succeeded;
	foreach my $handle (@$handles) {

		my $nodeurl = $handle->{url} . '/node/' . $handle->{id};
		my $ua = LWP::UserAgent->new();

		my $header = HTTP::Headers->new('Authorization' => "OAuth " . $admin_token) ;

                $ua->default_headers($header);

                my $getResult = $ua->get($nodeurl."/acl?verbosity=full");
                if (!$getResult->is_success) {
			$succeeded{$handle->{hid}} = 0;
			warn "Error: " . $getResult->message;
			warn "Error: " . $getResult->content;
                        next;                    
                }
                
                my $jsonAcls=from_json($getResult->content);
                my $users=$jsonAcls->{'data'}{'read'};
                
                if (grep { $_->{'username'} eq $username } @$users) {
		    $succeeded{$handle->{hid}} = 1;
                    warn "$username already has read access on $nodeurl, skipping PUT";
                    next;
                }

                warn "setting read ACL on $nodeurl for $username";

		my $req = new HTTP::Request("PUT",$nodeurl."/acl/read?users=$username",HTTP::Headers->new('Authorization' => "OAuth " . $admin_token));
		$ua->prepare_request($req);
		my $put = $ua->send_request($req);
		if ($put->is_success) {
			$succeeded{$handle->{hid}} = 1;
			warn "Success: " . $put->message;
			warn "Success: " . $put->content;
		}
		else {
			$succeeded{$handle->{hid}} = 0;
			warn "Error: " . $put->message;
			warn "Error: " . $put->content;
		}
	}
	my @failed = ();
	foreach my $hid (@$hids) {
		if (!($succeeded{$hid})) {
			push @failed, $hid;
		}
	}
	if (@failed) {
		die "Unable to set acl(s) on handles " . join(", ", @failed);
	}


    #END add_read_acl
    return();
}




=head2 set_public_read

  $obj->set_public_read($hids)

=over 4

=item Parameter and return types

=begin html

<pre>
$hids is a reference to a list where each element is a HandleMngr.HandleId
HandleId is a string

</pre>

=end html

=begin text

$hids is a reference to a list where each element is a HandleMngr.HandleId
HandleId is a string


=end text



=item Description

The set_public_read function will update the acl of the shock
node that the handle references to make the node globally readable.
The function is only accessible to a specific list of users specified
at startup time.

=back

=cut

sub set_public_read
{
    my $self = shift;
    my($hids) = @_;

    my @_bad_arguments;
    (ref($hids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"hids\" (value was \"$hids\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_public_read:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_public_read');
    }

    my $ctx = $Bio::KBase::HandleMngr::HandleMngrServer::CallContext;
    #BEGIN set_public_read

	my $has_user = 0;
	foreach my $user (@{$self->{allowed_users}}) {
		if ($user eq $ctx->{user_id}) {
			$has_user = 1;
			last;
		}
	}
	if (!$has_user) {
		die "User $ctx->{user_id} may not run the set_public_read method"
	}
	

	my $client;
	# given a list of handle ids, get the handles
	if ($self->{handle_url}) {
		$client = Bio::KBase::HandleService->new($self->{handle_url});
	} else {
		$client = Bio::KBase::HandleService->new();
	}
	my $handles = $client->hids_to_handles($hids);
	
	# given a list of handles, update the acl of handle->{id}
	my $admin_token = $self->{'admin-token'};
	my %succeeded;
	foreach my $handle (@$handles) {

		my $nodeurl = $handle->{url} . '/node/' . $handle->{id};
		my $ua = LWP::UserAgent->new();

		my $header = HTTP::Headers->new('Authorization' => "OAuth " . $admin_token) ;

                $ua->default_headers($header);

                my $getResult = $ua->get($nodeurl."/acl?verbosity=full");
                if (!$getResult->is_success) {
			$succeeded{$handle->{hid}} = 0;
			warn "Error: " . $getResult->message;
			warn "Error: " . $getResult->content;
                        next;                    
                }

                my $jsonAcls=from_json($getResult->content);

                if ($jsonAcls->{'data'}{'public'}{'read'}) {
		    $succeeded{$handle->{hid}} = 1;
                    warn "public already has read access on $nodeurl, skipping PUT";
                    next;
                }

                warn "setting read ACL on $nodeurl for public";

		my $publicReadUrl = $handle->{url} . '/node/' . $handle->{id} . "/acl/public_read";
		my $req = new HTTP::Request("PUT", $publicReadUrl, HTTP::Headers->new('Authorization' => "OAuth " . $admin_token));
		$ua->prepare_request($req);
		my $put = $ua->send_request($req);
		if ($put->is_success) {
			$succeeded{$handle->{hid}} = 1;
			warn "Success: " . $put->message;
			warn "Success: " . $put->content;
		}
		else {
			$succeeded{$handle->{hid}} = 0;
			warn "Error: " . $put->message;
			warn "Error: " . $put->content;
		}
	}
	my @failed = ();
	foreach my $hid (@$hids) {
		if (!($succeeded{$hid})) {
			push @failed, $hid;
		}
	}
	if (@failed) {
		die "Unable to set acl(s) on handles " . join(", ", @failed);
	}
    #END set_public_read
    return();
}




=head2 status 

  $return = $obj->status()

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

Return the module status. This is a structure including Semantic Versioning number, state and git info.

=back

=cut

sub status {
    my($return);
    #BEGIN_STATUS
    $return = {"state" => "OK", "message" => "", "version" => $VERSION,
               "git_url" => $GIT_URL, "git_commit_hash" => $GIT_COMMIT_HASH};
    #END_STATUS
    return($return);
}

=head1 TYPES



=head2 HandleId

=over 4



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
