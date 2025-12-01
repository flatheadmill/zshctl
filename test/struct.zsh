source share/zshctl/zshctl/include/struct.zsh

# If we find a use for it, we can add shift, pop or delete.
function {
    typeset -A struct=( existing 1 ) assoc
    typeset array=( one two three )
    # We are going to put an associative array at `assoc`.
    printf 'assoc exists: %s, existing exists: %s\n' ${+struct[assoc]} ${+struct[existing]}
    # Put a value into the assoc key. This can be an array or an associative
    # array, it's up to you to get the associative array pairing right.
    struct put struct assoc first 1 second 2 third 3
    # Now we have a key called `assoc`.
    printf 'assoc exists: %s, existing exists: %s\n' ${+struct[assoc]} ${+struct[existing]}
    # Read the value back out of the struct.
    struct get struct assoc assoc
    printf 'assoc value: %s\n' ${(j: :)${(@kvqq)assoc}}
    printf 'assoc exists: %s, existing exists: %s\n' ${+struct[assoc]} ${+struct[existing]}
    # We can add to an existing element.
    struct push struct assoc four 4
    struct get struct assoc assoc
    printf 'assoc value: %s\n' ${(j: :)${(@kvqq)assoc}}
    struct push struct missing four 4
    struct get struct missing assoc
    printf 'assoc value: %s\n' ${(j: :)${(@kvqq)assoc}}
    struct put struct array 1 2 3
    struct get struct array array
    printf 'array value: %s\n' ${(j: :)${(@qq)array}}
}
