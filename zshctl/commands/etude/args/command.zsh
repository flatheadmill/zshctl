function :help:etude:args {
    heredoc <<'    EOF'
    terse: an exercise of the \`${__program__}\` argument parser
    arguments:
    - name: help
      description: Display conext sensitive help.
    - name: map
      description: Add a key value pair to a map.
      tail: |
          What would you do here? Grab the first sentance? Are you always
          going to be able to find the first sentance.
      description: |
        Add a key value pair to a map.
        What would you do here? Grab the first sentance? Are you always going to
        be able to find the first sentance. Yes, with a newline, you can find
        the first sentance and paragraphs are started with two newlines, so for
        your short description, always grab the first line.
      keys: [ one, two, three ]
    - name: array
      description: \HTML combobulator.
    verbose: |
        An exercise of the \`${__program__}\` argument parser.
    body: |
        # Description

        An exercise of the \`${__program__}\` argument parser.

        How complicated can I get with this? How would I do a minimal Markdown
        or other sort of syntax highlighting.

        What am I already using? For this I would need a minimal Zsh markup
        language that is just a subset of Markdown, enough to do lists, bold,
        highlights and subscripts. Something that is the set of items in man.

        Thus, I could do `keywords`, and I could do *bold* but no point in doing
        italics, really, since they would render as keywords.

        Then I could have code blocks.

        ```
        for (let i = 0; i < 10; i++) {
            console.log(`The value is ${i}.`)
        }

        ```

        And I suppose I could try to do links, but they would only ever appear
        to be links, and parsing email is impossible, so forget that.

        # See Also

        Basic headings, of course.

        What about lists? Those would be stretch goal.

         * Best case it is one line.
         * Worst case it is a long line that will have to wrap at some point
           because there are so man words in the line.

        From here I would have to create a man page from all this, but now I am
        not trying to teach people man pages, I'm rendering man pages, and
        perhaps I am also rendering HTML help.

        Having done this, I've made `gojq` a dependency of `zshctl`, at least
        the help system, and the parser itself is written in Zsh.

        Already, I can see that I am far more likely to write help in this
        language than in man, which is turning out to be a real nusiance.
        Running `gojq` is going to be faster than trying to parse all the man
        pages.
    EOF
}
# ___ body ___
#
# ___ :execute:etude:args _ man ___
# .SH NAME
# .PG __program__\ etude\ args \-
# an exercise of the
# .PG .B __program__
# argument parser
# .SH SYNOPSIS
# .PG .SY __program__\ etude\ args
# .RI [ arguments ]
# .PG .SY __program__\ etude\ args
# .RB [ \-h | \-\-help ]
# .YS
# .DC An exercise of the
# .PG .B __program__
# argument parser.
# .SH DESCRIPTION
# An exercise of the
# .PG .BR __program__
# argument parser.
#
# An example of the argument parser with an example of the basic completion
# mechanism.
# .SH OPTIONS
# .TP
# .BR \-a ,\  \-\-array = \fIitem\fR
# .br
# .DC Add value to an array element.
# .TP
# .B \-m
# .IR key = value ,
# .B \-m
# .IR key\ value ,
# .B \-\-map
# .IR key = value ,
# .B \-\-map
# .I key\ value
# .br
# .DC Add value to an array element.
# .HP
# .BR \-h ,\  \-\-help
# .br
# .DC Help for
# .PG .BR __program__\ extend .
# ___
function :args:etude:args {
    eval "$(args -U -a a,array -A m,map -- "$@")"
}

function :execute:etude:args {
    print o_array
    print -- "${(@qq)o_array}"
    print o_map
    print -- "${(@kvqq)o_map}"
}

function :complete:etude:args {
}
