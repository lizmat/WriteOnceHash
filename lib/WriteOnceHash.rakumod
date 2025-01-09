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

# vim: expandtab shiftwidth=4
