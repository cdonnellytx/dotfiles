/** 
 * SQLCL statusbar.
 * 
 * ORACRAP:
 *  - [23.4] They have a "default" mode for the statusbar and you can set it back to default.
 *    To *use* the default, however, you have to call "set statusbar default" _again_.
 *  - [23.4] Git only shows the current branch.  But it _does_ cause a noticeable delay, so I leave it off.
 *  - [23.4] AFAIK statusbar can't have any styling.
 */
set statusbar on
set statusbar default editmode encoding username dbid txn linecol cwd timing 
set statusbar default

