# Mutt as Alpine

`muttrc` makes mutt 2.2 behave as much like my Alpine as mutt allows: Alpine
2.26 plus the patches on
[0xkag/alpine custom-2.26.x](https://github.com/0xkag/alpine/tree/custom-2.26.x)
(fancy, compose, tome, ...), configured by `alpine/pinerc`.  Key choices come
from that branch's `alpine/keymenu.c`.

## Files

- `muttrc`: keys and behavior, the same everywhere.
- `~/.dotfiles/_sites/current/mutt/muttrc.local`: accounts and identity for
  this site, next to the site pinerc.  Sourced last if it exists.
- `~/.dotfiles/_sites/current/mutt/mutt_oauth2.py`: mutt's OAuth2 helper for
  gmail, with the token file encrypted to my GPG key.

## Setup

1. `ln -s ~/.dotfiles/mutt/muttrc ~/.muttrc` (`dotfiles-install` doesn't do
   this).
2. Install `aspell`, `aspell-en`, and `urlscan` (in
   `_reqs/requirements-ubuntu.txt`).
3. localhost IMAP: on first connect, answer `(a)ccept always` for its
   certificate.  This is Alpine's `/novalidate-cert`; the hostname check is
   already off for localhost.
4. gmail OAuth2, once:
   1. In the Google Cloud console, create a project, enable the Gmail API, set
      up the OAuth consent screen (External, with me as a test user), and
      create an OAuth client ID of type Desktop app.
   2. Put its client ID and secret into `registrations['google']` in
      `mutt_oauth2.py`.
   3. Run `mutt_oauth2.py --verbose --authorize ~/.mutt-oauth2-gmail.tokens`
      and choose `google`, `localhostauthcode` (Google retired the plain
      `authcode` flow), and `kyle.a.george@gmail.com`.
   4. Check with `mutt_oauth2.py --verbose --test ~/.mutt-oauth2-gmail.tokens`.

   Decrypting the token file needs a pinentry, so `GPG_TTY` must be set in the
   shell.

## Keys

Alpine commands are case-insensitive; mutt's are not.  Only the lowercase
Alpine keys are bound, so uppercase keys keep their mutt meanings (`D`
delete-pattern, `L` list-reply, `N` toggle-new, `T` tag-pattern, ...), except
`R`, which is reply-to-all.  Since `:` is SelectCur, mutt's command line is
`Esc :`.

| Screen | Alpine keys | Notes |
|---|---|---|
| Everywhere | `n` `p` arrows, Space `+` `^V` / `-` `^Y`, `w` `^W`, `:` | next/prev (arrows scroll lines in the viewer), page, WhereIs, SelectCur |
| Index | `>` `v` `.` Enter, `<` `,` `l`, `g`, `c`, `r` `f` `s` `e` `t` `d` `u`, `%` `*` `\|` `b` `h` `j` `$`, Tab | view, folder list, goto, compose, ..., print, flag, pipe, bounce, headers, jump, sort, next new |
| Index | `;` `a` `z` `&` | Select (mutt pattern), Apply, Zoom, unXclude |
| Index | `x` | eXpunge, after "Purge N deleted messages?" |
| Index | `/` `[` `]`, `{` `}`, `(` `)`, `^R` `^U` `^T` | fancy patch: collapse/expand thread, all threads, prev/next thread, delete/undelete/select thread |
| Viewer | `i` `<` `,` / `>` `v` `.` / `q` | index / attachments / quit (asks first) |
| Viewer | `^B` `^F` | URLs, via urlscan |
| Attachments | `<` `,` `i` / `>` `v` `.` Enter / `e` `%` `x` | exit / view / export, print, external viewer |
| Folder list | `<` `,` `i` / `>` `v` `.` Enter / `a` `d` `r` | exit / open / add, delete, rename |
| Compose | `^X` `^O` `^J` | spell check then send, postpone, attach |

## Behavior

| pinerc | mutt |
|---|---|
| `expunge-only-manually` | Closing or quitting never purges; only `x` does |
| `incoming-startup-rule=last` | Start on the last message |
| `sort-key` (Arrival) | `sort=mailbox-order` |
| `index-format` | `%Z %4C %[%b %d %R] %-25.25F (%4c) %s` |
| tome patch | `+` sole recipient, `.` one of several |
| `convert-dates-to-localtime` | Index dates are local (`%[...]`) |
| `include-text-in-reply`, `forward-as-attachment` | `include=yes`, `mime_forward=yes` |
| `spell-check-before-sending` | `^X` runs aspell, then sends |
| Composer, `customized-hdrs=From:` | nvim with headers above the body |
| `viewer-overlap` | `pager_context=2`; Space stops at the end of a message |
| "Really quit Alpine?" | `quit=ask-yes` |
| `mail-check-interval=30` | `mail_check=30`, `timeout=30` |
| Delay-removal patch | `sleep_time=0` |
| `user-domain`, `alt-addresses` | `hostname`, `alternates` |
| Gmail role | Reply/forward from the address mail was sent to; compose as gmail in gmail folders |

## Differences from Alpine

- No prompt menus.  Reply doesn't ask about reply-to-all (use `R`).  Select
  takes a pattern (`~f`, `~s`, `~d`, ...).  `*` only toggles Important.
- Zoom doesn't toggle; `&` unzooms.
- No role prompt or `#`.  From: is in the editor's headers, and the compose
  screen's `Esc f` changes it.  Replies and forwards come from whichever
  alternate address the message went to, including gatech, himark, and
  kylegeorge.com, not just gmail.
- The compose patch's "compose to sender" is mutt's `<compose-to-sender>`,
  unbound.
- `saved-msg-name-rule=last-folder-used` has no equivalent; press Up at the
  save prompt.
- mutt 2.2 `index_format` has no SMARTTIME, percentage widths, or keywords
  (SUBJKEY).  Index colors color whole lines, not the status symbol, so
  pinerc colors aren't carried over.
- The viewer shows the Date: header as sent, not local time.
- One folder collection: `=` is localhost `mbox/`.  For others, `g` a URL
  (`imaps://imap.gmail.com/`), then `?` to list.
- URLs open through urlscan, not inline with Enter, and not through
  `url-viewers` (`writeurl`).
- `x` leaves "Purge?" on until the next folder open, so quitting after
  deleting more messages asks.
- Holding deleted messages until `x` relies on IMAP keeping `\Deleted`; local
  mbox and maildir folders drop the marks on close.
- mutt also uses the viewer for help and attachments, so `q` asks "Quit
  Mutt?" there too.  Answering yes in one of those only goes back a level,
  and then the next `q` quits without asking.  Use `i`, `<`, or `,` to back
  out.
- `^X` and aspell spell check the body only; `y` sends without checking.
