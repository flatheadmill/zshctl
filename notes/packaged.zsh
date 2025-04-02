function packaged {
    function _packaged_helper {
        print hello, $1
    }
    function packaged {
        _packaged_helper "$@"
    }
    packaged "$@"
}

function {
    packaged world
}
