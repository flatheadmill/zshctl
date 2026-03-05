#!/usr/bin/env python3
"""
Generate man-survey.html — a visual survey of man page option conventions.

To add a new program:
  1. Capture its man page:
       MANWIDTH=80 man <cmd> 2>/dev/null | cat > /tmp/<cmd>_man_raw.bin
  2. Add a section below following the existing pattern.
  3. Re-run this script.

The converter reads the raw overprint output that `man | cat` produces.
Overprint encoding: bold = char\x08char, underline = _\x08char.
These become <b> and <u> tags in the HTML preformatted blocks.
"""

import re
import sys


def overprint_to_html(path):
    with open(path, 'rb') as f:
        data = f.read()
    raw = data.decode('utf-8', errors='replace')
    i = 0
    result = []
    while i < len(raw):
        if i + 2 < len(raw) and raw[i + 1] == '\x08':
            a, b = raw[i], raw[i + 2]
            if a == '_':
                result.append(('u', b))
            elif a == b:
                result.append(('b', a))
            else:
                result.append(('', b))
            i += 3
        else:
            result.append(('', raw[i]))
            i += 1
    html = []
    prev = ''
    for tag, ch in result:
        if tag != prev:
            if prev:
                html.append(f'</{prev}>')
            if tag:
                html.append(f'<{tag}>')
            prev = tag
        html.append(ch)
    if prev:
        html.append(f'</{prev}>')
    return ''.join(html)


def extract(text, section):
    pat = rf'\n(?:<b>)?{section}(?:</b>)?\n(.*?)(?=\n(?:<b>)?[A-Z][A-Z /()-]{{2,}}(?:</b>)?\n|\Z)'
    m = re.search(pat, text, re.DOTALL)
    return m.group(1).rstrip() if m else ''


def first_n_options(opts_text, n=6):
    lines = opts_text.split('\n')
    entries = []
    current = []
    for line in lines:
        if re.match(r'^\s{0,6}<b>-', line) and current:
            entries.append('\n'.join(current))
            current = [line]
            if len(entries) >= n:
                break
        else:
            current.append(line)
    if current and len(entries) < n:
        entries.append('\n'.join(current))
    return '\n'.join(entries[:n])


def esc_pre(s):
    for i, tag in enumerate(['<b>', '</b>', '<u>', '</u>']):
        s = s.replace(tag, f'\x00{i}\x00')
    s = s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    for i, tag in enumerate(['<b>', '</b>', '<u>', '</u>']):
        s = s.replace(f'\x00{i}\x00', tag)
    return s


CSS = '''
  body {
    background: #1e1e1e;
    color: #d4d4d4;
    font-family: Georgia, serif;
    max-width: 900px;
    margin: 0 auto;
    padding: 2em;
    line-height: 1.7;
  }
  h1 { color: #ce9178; font-size: 1.6em; border-bottom: 1px solid #444; padding-bottom: 0.3em; }
  h2 { color: #9cdcfe; font-size: 1.2em; margin-top: 2em; }
  h3 { color: #4ec9b0; font-size: 1em; margin-top: 1.5em; margin-bottom: 0.3em; }
  p { color: #d4d4d4; }
  pre {
    background: #0d0d0d;
    border: 1px solid #333;
    border-left: 3px solid #4ec9b0;
    padding: 1em 1.2em;
    font-family: "Menlo", "Monaco", "Courier New", monospace;
    font-size: 0.88em;
    line-height: 1.5;
    overflow-x: auto;
    white-space: pre;
    color: #d4d4d4;
  }
  pre b { color: #ffffff; font-weight: bold; }
  pre u { color: #d7ba7d; text-decoration: underline; text-underline-offset: 2px; }
  .observation { color: #888; font-style: italic; margin: 0.5em 0 1.2em 0; }
  hr { border: none; border-top: 1px solid #333; margin: 2em 0; }
'''


def capture(cmd):
    """Capture a man page to /tmp if not already there."""
    import subprocess, os
    path = f'/tmp/{cmd}_man_raw.bin'
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        with open(path, 'wb') as f:
            subprocess.run(
                ['man', cmd],
                stdout=f, stderr=subprocess.DEVNULL,
                env={'MANWIDTH': '80', 'PATH': '/usr/bin:/bin:/usr/local/bin',
                     'HOME': '/Users/alan', 'TERM': 'dumb'}
            )
    return path


def section_html(title, observation, synopsis, options_or_other, other_label='Options'):
    return f'''
<h2>{title}</h2>
<p class="observation">{observation}</p>
<h3>Synopsis</h3>
<pre>{esc_pre(synopsis.strip())}</pre>
<h3>{other_label} (sample)</h3>
<pre>{esc_pre(options_or_other.strip()[:1000])}</pre>
'''


def build():
    parts = [f'<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
             f'<title>Man Page Option Conventions — A Survey</title>\n'
             f'<style>{CSS}</style>\n</head>\n<body>\n'
             f'<h1>Man Page Option Conventions</h1>\n'
             f'<p>A survey of how different programs and traditions document their arguments — '
             f'synopsis style, option presentation, value placeholders, and the typographic '
             f'conventions that vary by lineage. Written to inform what MAN DOWN! should be '
             f'able to express when rendering option declarations.</p>\n<hr>\n']

    # ls
    text = overprint_to_html(capture('ls'))
    syn = extract(text, 'SYNOPSIS')
    desc = extract(text, 'DESCRIPTION')
    opts = first_n_options(desc, 8)
    parts.append(section_html(
        'BSD <code>ls</code> — Short Flags, One Value Option',
        'The canonical BSD short-flag style. Flags cluster in a single bracket group. '
        'One value option (<code>--color=<i>when</i></code>) in long form. '
        'The <code>-D format</code> option shows a value argument as a bare italic word '
        'without brackets. No long equivalents for the short flags. Each flag in bold, '
        'value underlined, description on the same or following line.',
        syn, opts
    ))

    # grep
    text = overprint_to_html(capture('grep'))
    syn = extract(text, 'SYNOPSIS')
    opts = first_n_options(extract(text, 'OPTIONS'), 7)
    parts.append('<hr>\n' + section_html(
        'BSD <code>grep</code> — Short and Long, Clustered and Individual',
        'Mixed style: short flags cluster; options with values appear individually with the '
        'value underlined. Long options use <code>--binary-files=<i>value</i></code> '
        '(equals, no space) and <code>--color[=<i>when</i>]</code> (optional value in '
        'brackets). The optional-value bracket notation is a style not all renderers handle '
        'gracefully.',
        syn, opts
    ))

    # git
    text = overprint_to_html(capture('git'))
    syn = extract(text, 'SYNOPSIS')
    opts = first_n_options(extract(text, 'OPTIONS'), 5)
    parts.append('<hr>\n' + section_html(
        '<code>git</code> — Subcommand Delegation, Spare Top-Level Synopsis',
        'The top-level synopsis names global options and defers to <i>command</i> '
        '[<i>args</i>]. Real documentation lives in per-command man pages. Each option '
        'on its own line with long and sometimes short form, value underlined, description '
        'on the next line with a blank line between entries — the GNU block style.',
        syn, opts
    ))

    # curl
    text = overprint_to_html(capture('curl'))
    syn = extract(text, 'SYNOPSIS')
    opts = first_n_options(extract(text, 'OPTIONS'), 6)
    parts.append('<hr>\n' + section_html(
        '<code>curl</code> — Long and Short Paired, Exhaustive Options',
        'curl shows short and long on the same line separated by a comma, value placeholder '
        'underlined. The synopsis defers with an ellipsis — full enumeration would be absurd. '
        'curl\'s man page is maintained by hand and is notably well-written prose.',
        syn, opts
    ))

    # find
    text = overprint_to_html(capture('find'))
    syn = extract(text, 'SYNOPSIS')
    primaries = extract(text, 'PRIMARIES')
    parts.append('<hr>\n' + section_html(
        '<code>find</code> — Positional Expressions, Not Options',
        'find\'s arguments are predicates composed into an expression, not flags. '
        'The synopsis shows <i>path</i> and <i>expression</i>. The PRIMARIES section '
        'lists each predicate. No flag clustering. This is what a command looks like when '
        'its argument grammar cannot be expressed as a flat list of options and values.',
        syn, primaries[:800], 'Primaries'
    ))

    # Synthesis
    parts.append('''<hr>
<h2>Observations on the Taxonomy</h2>

<h3>Bold for flags, underline for values</h3>
<p class="observation">Universal. Option flags are bold; value placeholders are underlined.
Bold means literal text the user types verbatim; underline means a slot to fill in.
MAN DOWN! uses backtick for bold and underscore for italic/underline — direct mapping.</p>

<h3>Short and long on the same line</h3>
<p class="observation">GNU style puts <code>-v</code>, <code>--verbose</code> on the same
line separated by a comma. BSD style often omits long forms from the options section.
This is the pairing that <code>_zshctl_help</code> generates by looking up the short alias
from <code>_zshctl_options</code>.</p>

<h3>Value syntax varies</h3>
<p class="observation"><code>--output=</code><u>file</u> (equals, no space),
<code>--output</code> <u>file</u> (space), <code>-o</code> <u>file</u> (short with space).
Optional: <code>--color[=</code><u>when</u><code>]</code>. Enumerated:
<code>--color=</code><u>always</u>|<u>never</u>|<u>auto</u>. The zshctl
<code>-- &lt; a | b | c &gt;</code> convention has no direct parallel in GNU style.</p>

<h3>Negation</h3>
<p class="observation">GNU: <code>--no-color</code> as a separate named option, or
<code>--[no-]color</code> in brackets in the synopsis. Positive and negative listed
separately in the options section if both appear. The zshctl <code>-!</code> flag
generates <code>--no-flagname</code> automatically.</p>

<h3>Arrays and maps</h3>
<p class="observation">No surveyed tool has a first-class array option concept in its man page.
Options that accumulate multiple values are shown once, with repetition behavior described
in prose. This is likely right for zshctl array options too.</p>

<h3>Counter and toggle</h3>
<p class="observation">Counters appear as options where "each use increments verbosity."
Toggles are rare — most tools use explicit <code>--enable-x</code> / <code>--disable-x</code>.
These are zshctl-specific patterns without a clear man page precedent.</p>

<hr>
<p style="color: #555; font-size: 0.85em;">
Provisional observations for the zshctl project. Subject to markup and correction.<br>
Survey: BSD ls, BSD grep, curl, git, find (macOS). Generated by notes/man-survey-generate.py.
</p>
</body>
</html>
''')

    return ''.join(parts)


if __name__ == '__main__':
    out_path = 'notes/man-survey.html'
    if len(sys.argv) > 1:
        out_path = sys.argv[1]
    html = build()
    with open(out_path, 'w') as f:
        f.write(html)
    print(f'Written {len(html):,} bytes to {out_path}', file=sys.stderr)
