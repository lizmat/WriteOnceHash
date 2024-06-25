use v6.d;

my constant DELETE = Mu.new;

class X::Hash::WriteOnce is Exception {
    has $.key;
    has Mu $.value;
    method message() {
        $!value =:= DELETE
          ?? "Can not delete '$!key'"
          !! $!key.defined
            ?? "Can not set '$!key' to '$!value' because it was already set"
            !! "Can not re-initialize a WriteOnceHash"
    }
}

role WriteOnce {

    # Need access to the original methods to prevent MMD collisions
    my &AT-KEY := ::?CLASS.^find_method('AT-KEY');

    method !STORE-FROM-ITERABLE(\iterable --> Int:D) {
        my $iterator := iterable.iterator;
        my $added = 0;
        my $pulled;
        my $value;

        until ($pulled := $iterator.pull-one) =:= IterationEnd {

            # process a pair
            if $pulled ~~ Pair {
                self.BIND-KEY($pulled.key, $pulled.value<>);
                ++$added;
            }

            # a Map and not a container, sub-process the Map
            elsif $pulled ~~ Map && $pulled.VAR.^name eq $pulled.^name {
                $added += self!STORE-FROM-ITERABLE($pulled)
            }

            # just a key, get the value and process
            elsif ($value := $iterator.pull-one) =:= IterationEnd {
                $pulled ~~ Failure
                  ?? $pulled.throw
                  !! X::Hash::Store::OddNumber.new(
                       found => $added * 2 + 1,
                       last  => $pulled
                     ).throw;

                self.BIND-KEY($pulled, $value<>);
                ++$added;
            }
        }

        $added
    }

    # interface methods we need to override
    method AT-KEY(::?CLASS:D: $key is raw) is raw {
        self.EXISTS-KEY($key)
          ?? AT-KEY(self, $key)
          !! Proxy.new(
               FETCH => -> $ { AT-KEY(self, $key) },
               STORE => -> $, $value is raw {
                 self.EXISTS-KEY($key)
                   ?? X::Hash::WriteOnce.new( :$key, :$value ).throw
                   !! self.BIND-KEY($key, $value<>)
               }
             )
    }

    method ASSIGN-KEY(::?CLASS:D: $key is raw, $value is raw) is raw {
        self.EXISTS-KEY($key)
          ?? X::Hash::WriteOnce.new( :$key, :$value ).throw
          !! self.BIND-KEY($key, $value<>)
    }
    method DELETE-KEY(::?CLASS:D: $key is raw) {
         X::Hash::WriteOnce.new( :$key, :value(DELETE) ).throw
    }
    method STORE(::?CLASS:D: \iterable, :$INITIALIZE) {
        $INITIALIZE
          ?? self!STORE-FROM-ITERABLE(iterable)
          !! X::Hash::WriteOnce.new.throw
    }
}

class WriteOnceHash is Hash does WriteOnce { }

=begin pod

=head1 NAME

WriteOnceHash - be a Hash in which each key can only be set once

=head1 SYNOPSIS

=begin code :lang<raku>

use WriteOnceHash;

# bind to predefined class
my %woh is WriteOnceHash;
%woh<a> = 5; # ok
%woh<a> = 1; # throws

CATCH {
    when X::Hash::WriteOnce {
        say "Sorry, already set {.key} before";
        .resume
    }
}

# mix in role on anything that does Associative
my %owoh{Any} does WriteOnce;

=end code

=head1 DESCRIPTION

This module makes an C<WriteOnceHash> class available that can be used
instead of the normal C<Hash>.  The only difference with a normal
C<Hash> is, is that if an attempt is made to set the value of a key that
B<has already been set before>, an exception is thrown rather than just
overwriting the key in the C<Hash>.

Also binding to non-existing keys in the hash, and then assigning to the
obtained container, will only work once.  Iterating over values of the
hash will only yield values, not containers (as a normal C<Hash> would).

Also exports a C<X::Hash::WriteOnce> error class that will be thrown
if an attempt is made to set a key again.

The underlying C<WriteOnce> role is also exported that can be used on
objects that perform the C<Associative> role that are not C<Hash> (such
as object hashes).

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/WriteOnceHash .
Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2018, 2020, 2021, 2024 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify
it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
