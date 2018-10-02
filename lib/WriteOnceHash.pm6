use v6.c;

class X::Hash::WriteOnce is Exception {
    has $.key;
    has $.value;
    method message() {
        "Not allowed to set '{$!key}' to '$!value' because it was already set"
    }
}

role WriteOnce {

    # Need access to the original AT-KEY to prevent MMD collisions
    my $AT-KEY = ::?CLASS.^find_method('AT-KEY');
    my $STORE  = ::?CLASS.^find_method('STORE');

    method !STORE-AT-KEY($key is raw, $value is raw) is raw {
        self.EXISTS-KEY($key)
          ?? X::Hash::WriteOnce.new( :$key, :$value ).throw
          !! self.BIND-KEY($key, $value<>)
    }

    # interface method we need to override
    method AT-KEY(::?CLASS:D: $key is raw) is raw {
        Proxy.new(
          FETCH => -> $                { $AT-KEY(self,$key) },
          STORE => -> $, $value is raw { self!STORE-AT-KEY($key,$value) }
        )
    }
    method ASSIGN-KEY(::?CLASS:D: $key is raw, $value is raw) is raw {
         self!STORE-AT-KEY($key,$value)
    }
    method STORE(::?CLASS:D: \iterable) {
        $STORE(self,iterable.map: { $_<> })
    }
}

class WriteOnceHash:ver<0.0.1>:auth<cpan:ELIZABETH>
  is Hash
  does WriteOnce
{ }

=begin pod

=head1 NAME

WriteOnceHash - be a Hash in which each key can only be set once

=head1 SYNOPSIS

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
    my %owoh{Any} is WriteOnce;

=head1 DESCRIPTION

This module makes an C<WriteOnceHash> class available that can be used
instead of the normal C<Hash>.  The only difference with a normal
C<Hash> is, is that if an attempt is made to set the value of a key that
B<has already been set before>, that then an exception is thrown rather
than just overwriting the key in the C<Hash>.

Also exports a C<X::Hash::WriteOnce> error class that will be thrown
if an attempt is made to set a key again.

The underlying C<WriteOnce> role is also exported that can be used on
objects that perform the C<Associative> role that are not C<Hash> (such
as object hashes).

=head1 AUTHOR

Elizabeth Mattijsen <liz@wenzperl.nl>

Source can be located at: https://github.com/lizmat/WriteOnceHash .
Comments and Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: ft=perl6 expandtab sw=4
