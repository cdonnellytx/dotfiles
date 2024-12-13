" PL/SQL fixes

" Keywords as of 12.1
"  with builtins as (
"         select * from DBA_PROCEDURES p
"          where p.OWNER = 'SYS'
"            and p.OBJECT_NAME in ('STANDARD', 'DBMS_STANDARD')
"            and p.OVERLOAD = 1
"       )
"      ,typewith as (
"         select t.TYPE_NAME
"           from DBA_TYPES t
"          where t.OWNER is null
"       )
"      ,driver as (
"         select (
"                 case
"                     when regexp_like(v.KEYWORD, '[^[:alnum:]_#$]') then '"' || replace(v.KEYWORD, '', '\') || '"'
"                     else v.KEYWORD
"                 end
"                ) as keyword
"               ,(
"                 case
"                     when t.TYPE_NAME is not null then 'plsqlStorage'
"                     when b.OBJECT_NAME is not null then 'plsqlFunction'
"                     else 'plsqlKeyword'
"                 end
"                ) as GP
"            from V$RESERVED_WORDS v
"                 left outer join BUILTINS b on b.PROCEDURE_NAME = v.KEYWORD
"                 left outer join TYPEWITH t on t.TYPE_NAME = v.KEYWORD
"           where regexp_like(v.keyword, '^\w')
"           order by v.Keyword
"      )
" select 'syn keyword ' || GP  || ' ' || Commons.ClobHelper.Join(' ', cast(collect(KEYWORD order by KEYWORD) as Commons.Varchars)) as TEXT
"   from driver
"  group by GP
"  order by GP
" /
"


" Don't match identifiers > 128 chars
syn match plsqlError "[a-z][a-z0-9$_#]\{128,\}"     " VIMCRAP: Cygwin Vim 7.3, Win32 gVim 7.4 seems to flake out if the first letter is uppercase
syn match plsqlError ":[a-z][a-z0-9$_#]\{128,\}"    " VIMCRAP: Cygwin Vim 7.3, Win32 gVim 7.4 seems to flake out if the first letter is uppercase
syn match plsqlError "\"[^"]\{129,\}\""


" SQL*Plus identifiers
syn match plsqlHostIdentifier "\v\&[1-9]"                             " SQL*Plus define (numbered params 1..9)
syn match plsqlHostIdentifier "\v\&?\&[_a-z][a-z0-9$_#]{0,29}"        " SQL*Plus define
syn match plsqlError          "\v\&?\&[_a-z][a-z0-9$_#]{30,}"         " SQL*Plus define
syn match plsqlHostIdentifier "\v\&?\&[_a-z][a-z0-9$_#]{0,29}"        " SQL*Plus define


" Additional keywords from TOAD
syn keyword plsqlStorage NVARCHAR POSITIVE POSITIVEN
syn keyword plsqlFunction dbms_alert dbms_application_info dbms_aq dbms_aqadm dbms_aqelm dbms_backup_restore dbms_ddl dbms_debug dbms_defer dbms_defer_query dbms_defer_sys dbms_describe dbms_distributed_trust_admin dbms_fga dbms_flashback dbms_hs_passthrough dbms_iot dbms_job dbms_ldap dbms_libcache dbms_lob dbms_lock dbms_logmnr dbms_logmnr_cdc_publish dbms_logmnr_cdc_subscribe dbms_logmnr_d dbms_metadata dbms_mview dbms_obfuscation_toolkit dbms_odci dbms_offline_og dbms_offline_snapshot dbms_olap dbms_oracle_trace_agent dbms_oracle_trace_user dbms_outln dbms_outln_edit dbms_output dbms_pclxutil dbms_pipe dbms_profiler dbms_random dbms_rectifier_diff dbms_redefinition dbms_refresh dbms_repair dbms_repcat dbms_repcat_admin dbms_repcat_instatiate dbms_repcat_rgt dbms_reputil dbms_resource_manager dbms_resource_manager_privs dbms_resumable dbms_rls dbms_rowid dbms_session dbms_shared_pool dbms_snapshot dbms_space dbms_space_admin dbms_sql dbms_standard dbms_stats dbms_trace dbms_transaction dbms_transform dbms_tts dbms_types dbms_utility dbms_wm dbms_xmlgen dbms_xmlquery dbms_xmlsave debug_extproc deleting outln_pkg plitblm raise_application_error sdo_cs sdo_geom sdo_lrs sdo_migrate sdo_tune set_transaction_use standard utl_coll utl_encode utl_file utl_http utl_inaddr utl_pg utl_raw utl_ref utl_smtp utl_tcp utl_url
syn keyword plsqlException dbms_lob.access_error dbms_lob.invalid_directory dbms_lob.noexist_directory dbms_lob.nopriv_directory dbms_lob.open_toomany dbms_lob.operation_failed dbms_lob.unopened_file
syn keyword plsqlException dbms_sql.inconsistent_type
syn keyword plsqlException utl_file.internal_error utl_file.invalid_filehandle utl_file.invalid_mode utl_file.invalid_operation utl_file.invalid_path utl_file.read_error utl_file.write_error

" ORACLE_LOADER
syn keyword plsqlKeyword ORACLE_LOADER characterset discardfile nodiscardfile logfile nologfile badfile nobadfile

" Various types of comments.
syntax region sqlplusPrompts start="\v^\s*conn(ect)?>" skip="\\$" end="$" keepend
syntax region sqlplusPrompts start="\v^\s*hos(t)?>" skip="\\$" end="$" keepend
syntax region sqlplusPrompts start="\v^\s*pause>" skip="\\$" end="$" keepend
syntax region sqlplusPrompts start="\v^\s*pro(mpt)?>" skip="\\$" end="$" keepend
syntax region sqlplusPrompts start="\v^\s*spo(ol)?>" skip="\\$" end="$" keepend

" BUGBUG: plsqlCommentL erroneously says backslash+EOL is a continuation.  It's not.
syntax region plsqlCommentL start="--" end="$" keepend contains=@plsqlCommentGroup,plsqlSpaceError
syntax region plsqlCommentL start="\<rem\>" end="$" keepend contains=@plsqlCommentGroup,plsqlSpaceError
syntax region sqlplusInclude start="^@" end="$" keepend

" Special: don't highlight these punctuation uses as errors
syn match sqlplusProxyLogin "\v\w+\[\w+\]"              " e.g. scott[bob]
syntax region sqlplusProxyLogin start="\[" end="\]\|$" keepend

" Matches multi-line string literals.
syntax match  plsqlOracleLoaderFilename  "\w\+\s*:\s*'\([^']\|\r\|\n\|''\)*'"

"------------------------------------------------------------------------------------------
" Highlights
"------------------------------------------------------------------------------------------

hi def link sqlplusInclude Include
hi def link plsqlOracleLoaderFilename Identifier
hi def link sqlplusComment      Comment
hi def link sqlplusPrompts      PreCondit
hi def link plsqlPreCondit      PreCondit

"------------------------------------------------------------------------------------------
" Sync
"------------------------------------------------------------------------------------------
syn sync minlines=500 maxlines=5000
syn sync ccomment plsqlComment
syn sync ccomment plsqlCommentL
syn sync ccomment sqlplusComment
syn sync ccomment sqlplusPrompts

" vim: noexpandtab sts=8 ts=8 sw=2

