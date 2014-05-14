package MediaWords::ActionRole::Logged;

#
# Action role that logs requests
#

use strict;
use warnings;

use Modern::Perl "2013";
use MediaWords::CommonLibs;

use Moose::Role;
use namespace::autoclean;

use Data::Dumper;
use MediaWords::DBI::Auth;

use constant NUMBER_OF_REQUESTED_ITEMS_KEY => 'MediaWords::ActionRole::Logged::requested_items_count';

after execute => sub {
    my ( $self, $controller, $c ) = @_;

    my $user_email = undef;
    my $user_roles = undef;
    if ( $c->user )
    {
        $user_email = $c->user->username;
        $user_roles = $c->user->roles;
    }
    else
    {
        my $api_auth = undef;
        if ( $c->stash->{ api_auth } )
        {
            $api_auth = $c->stash->{ api_auth };
        }
        else
        {
            $api_auth = MediaWords::DBI::Auth::user_for_api_token_catalyst( $c );
        }
        if ( $api_auth )
        {
            $user_email = $api_auth->{ email };
            $user_roles = $api_auth->{ roles };
        }
    }
    unless ( $user_email and $user_roles )
    {
        die "user_email is undef (I wasn't able to authenticate either using the API key nor the normal means)";
    }

    my $request_path = $c->req->path;
    unless ( $request_path )
    {
        die "request_path is undef";
    }

    my $requested_items_count = $c->stash->{ NUMBER_OF_REQUESTED_ITEMS_KEY } // 1;

    # Log the request
    my $db = $c->dbis;

    $db->begin_work;

    $db->query(
        <<EOF,
        INSERT INTO auth_user_requests (email, request_path, requested_items_count)
        VALUES (?, ?, ?)
EOF
        $user_email, $request_path, $requested_items_count
    );

    $db->commit;
};

# Static helper that sets the number of requested items (e.g. stories) in the Catalyst's stash to be later used by after{}
sub set_requested_items_count($$)
{
    my ( $c, $requested_items_count ) = @_;

    # Will use it later in after{}
    $c->stash->{ NUMBER_OF_REQUESTED_ITEMS_KEY } = $requested_items_count;
}

1;
