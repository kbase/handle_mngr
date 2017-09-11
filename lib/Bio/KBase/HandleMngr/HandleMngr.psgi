use Bio::KBase::HandleMngr::HandleMngrImpl;

use Bio::KBase::HandleMngr::HandleMngrServer;
use Plack::Middleware::CrossOrigin;



my @dispatch;

{
    my $obj = Bio::KBase::HandleMngr::HandleMngrImpl->new;
    push(@dispatch, 'HandleMngr' => $obj);
}


my $server = Bio::KBase::HandleMngr::HandleMngrServer->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler = Plack::Middleware::CrossOrigin->wrap( $handler, origins => "*", headers => "*");
