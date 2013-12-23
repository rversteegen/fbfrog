'' Main module, command line interface

#include once "fbfrog.bi"

dim shared verbose as integer

private sub hPrintHelp( byref message as string )
	if( len( message ) > 0 ) then
		print message
	end if
	print "fbfrog 0.1 (" + __DATE_ISO__ + "), FreeBASIC binding generator"
	print "usage: fbfrog [options] *.h"
	print "Generates a .bi file containing FB API declarations corresponding"
	print "to the C API declarations from the given *.h file(s)."
	print "options:"
	print "  -nomerge   Don't preserve code from #includes"
	print "  -w         Whitespace: Try to preserve comments and empty lines"
	print "  -o <path>  Set output directory for generated .bi files"
	print "  -v         Show verbose/debugging info"
	end (iif( len( message ) > 0, 1, 0 ))
end sub

private function frogDownload( byref url as string, byref file as string ) as integer
	var downloadfile = "tarballs" + PATHDIV + file
	if( hFileExists( downloadfile ) ) then
		function = TRUE
	else
		hMkdir( "tarballs" )
		if( hShell( "wget '" + url + "' -O """ + downloadfile + """" ) ) then
			function = TRUE
		else
			hKill( downloadfile )
			function = FALSE
		end if
	end if
end function

private function frogExtract( byref tarball as string, byref dirname as string ) as integer
	hMkdir( dirname )

	dim s as string

	if( strEndsWith( tarball, ".zip" ) ) then
		s = "unzip -q"
		s += " -d """ + dirname + """"
		s += " ""tarballs/" + tarball + """"
	elseif( strEndsWith( tarball, ".tar.gz" ) or _
	        strEndsWith( tarball, ".tar.bz2" ) or _
	        strEndsWith( tarball, ".tar.xz" ) ) then
		s = "tar xf ""tarballs/" + tarball + """"
		s += " -C """ + dirname + """"
	end if

	if( len( s ) > 0 ) then
		function = hShell( s )
	else
		function = FALSE
	end if
end function

private function hPrettyTarget( byval v as ASTNODE ptr ) as string
	select case( v->attrib and ASTATTRIB__ALLTARGET )
	case ASTATTRIB_DOS   : function = "dos"
	case ASTATTRIB_LINUX : function = "linux"
	case ASTATTRIB_WIN32 : function = "win32"
	case else            : assert( FALSE )
	end select
end function

private function hPrettyVersion( byval v as ASTNODE ptr ) as string
	select case( v->class )
	case ASTCLASS_DUMMYVERSION
		return hPrettyTarget( v )

	case ASTCLASS_CONST
		if( typeIsFloat( v->dtype ) = FALSE ) then
			return v->vali & "." & hPrettyTarget( v )
		end if

	end select

	return astDumpInline( v )
end function

private function frogWorkRootFile _
	( _
		byval pre as FROGPRESET ptr, _
		byval presetcode as ASTNODE ptr, _
		byval targetversion as ASTNODE ptr, _
		byval rootfile as zstring ptr _
	) as ASTNODE ptr

	print "parsing: " + *rootfile + " (" + hPrettyVersion( targetversion ) + ")"

	tkInit( )

	var whitespace = ((pre->options and PRESETOPT_WHITESPACE) <> 0)

	cppInit( )

	if( presetcode ) then
		var child = presetcode->head
		while( child )

			select case( child->class )
			case ASTCLASS_NOEXPAND
				cppNoExpandSym( child->text )
			case ASTCLASS_PPDEFINE
				cppPreDefine( child )
				cppRemoveSym( child->text )
			case ASTCLASS_PPUNDEF
				cppPreUndef( child->text )
				cppRemoveSym( child->text )
			case ASTCLASS_REMOVE
				cppRemoveSym( child->text )
			end select

			child = child->next
		wend
	end if

	if( (pre->options and PRESETOPT_NOPP) = 0 ) then
		cppMain( rootfile, whitespace, (pre->options and PRESETOPT_NOMERGE) <> 0 )
	else
		cppMainForTestingIfExpr( rootfile, whitespace, ((pre->options and PRESETOPT_NOPPFOLD) = 0) )
	end if

	cppEnd( )

	tkRemoveEOLs( )
	tkTurnCPPTokensIntoCIds( )

	'' Parse C constructs
	var ast = cFile( )

	tkEnd( )

	''
	'' Work on the AST
	''
	if( (pre->options and PRESETOPT_NOPPFOLD) = 0 ) then
		astCleanUpExpressions( ast )
	end if
	'astRemoveParamNames( ast )
	astFixArrayParams( ast )
	astFixAnonUDTs( ast )
	astRemoveRedundantTypedefs( ast )
	if( (pre->options and PRESETOPT_NOAUTOEXTERN) = 0 ) then
		astAutoExtern( ast, ((pre->options and PRESETOPT_WINDOWSMS) <> 0), whitespace )
	end if
	astMergeDIVIDERs( ast )

	'' Put file's AST into a VERBLOCK, if a targetversion was given,
	'' in preparation for the astMergeFiles() call later
	if( targetversion ) then
		ast = astWrapFileInVerblock( ast, targetversion )
	end if

	function = ast
end function

private sub hOopsNoInputFiles( byval targetversion as ASTNODE ptr, byref presetfilename as string )
	var message = "no input files"
	if( len( presetfilename ) > 0 ) then
		message += " for "
		if( targetversion ) then
			message += "version " + emitAst( targetversion ) + " in "
		end if
		message += presetfilename
	end if
	oops( message )
end sub

private function frogWorkVersion _
	( _
		byval pre as FROGPRESET ptr, _
		byval targetversion as ASTNODE ptr, _
		byval presetcode as ASTNODE ptr, _
		byref presetfilename as string, _
		byref presetprefix as string _
	) as ASTNODE ptr

	var rootfiles = astNewGROUP( )

	var child = presetcode->head
	while( child )

		select case( child->class )
		case ASTCLASS_DOWNLOAD
			'' Download tarballs
			if( frogDownload( *child->text, *child->comment ) = FALSE ) then
				oops( "failed to download " + *child->comment )
			end if

		case ASTCLASS_EXTRACT
			'' Extract tarballs
			if( frogExtract( *child->text, presetprefix + *child->comment ) = FALSE ) then
				oops( "failed to extract " + *child->text )
			end if

		case ASTCLASS_FILE
			'' Input files
			astAppend( rootfiles, astNewTEXT( presetprefix + *child->text ) )

		case ASTCLASS_DIR
			'' Input files from directories
			astAppend( rootfiles, hScanDirectory( presetprefix + *child->text, "*.h" ) )

		end select

		child = child->next
	wend

	if( rootfiles->head = NULL ) then
		hOopsNoInputFiles( targetversion, presetfilename )
	end if

	var f = rootfiles->head
	while( f )
		f->expr = frogWorkRootFile( pre, presetcode, targetversion, f->text )
		f = f->next
	wend

	function = rootfiles
end function

private sub hPrintPresetVersions( byval versions as ASTNODE ptr, byval targets as integer )
	dim s as string

	var i = versions->head
	while( i )
		s += emitAst( i ) + ", "
		i = i->next
	wend
	s = left( s, len( s ) - 2 )
	if( len( s ) = 0 ) then
		s = "none specified"
	end if

	print "versions: " + s

	s = ""
	if( targets and ASTATTRIB_DOS   ) then s += "dos, "
	if( targets and ASTATTRIB_LINUX ) then s += "linux, "
	if( targets and ASTATTRIB_WIN32 ) then s += "win32, "
	s = left( s, len( s ) - 2 )

	print "targets: " + s
end sub

private sub frogWorkPreset _
	( _
		byval pre as FROGPRESET ptr, _
		byref presetfilename as string, _
		byref presetprefix as string _
	)

	dim as ASTNODE ptr files, versions, targetversions
	dim as integer targets

	versions = astCollectVersions( pre->code )
	targets = astCollectTargets( pre->code )

	'' If no targets given, assume all
	if( targets = 0 ) then
		targets = ASTATTRIB__ALLTARGET
	end if

	'' If no versions given, use a dummy, to hold the targets
	if( versions->head = NULL ) then
		astAppend( versions, astNew( ASTCLASS_DUMMYVERSION ) )
	end if

	if( verbose ) then
		hPrintPresetVersions( versions, targets )
	end if

	targetversions = astCombineVersionsAndTargets( versions, targets )

	'' There will always be at least one combined version; even if there
	'' were only targets and no versions, one dummy version per target will
	'' be used.
	assert( targetversions->head )

	var targetversion = targetversions->head

	'' For each version...
	do
		'' Determine preset code for that version
		var presetcode = astGet1VersionAndTargetOnly( pre->code, targetversion )

		'' Parse files for this version and combine them with files
		'' from previous versions if possible
		files = astMergeFiles( files, _
			frogWorkVersion( pre, targetversion, presetcode, presetfilename, presetprefix ) )

		astDelete( presetcode )

		targetversion = targetversion->next
	loop while( targetversion )

	var versiondefine = "__" + ucase( pathStripExt( pathStrip( presetfilename ) ), 1 ) + "_VERSION__"
	astProcessVerblocksAndTargetblocksOnFiles( files, versions, targets, versiondefine )

	'' Remove files that don't have an AST left, i.e. were combined into
	'' others and shouldn't be emitted individually anymore.
	var f = files->head
	while( f )
		if( f->expr = NULL ) then
			f = astRemove( files, f )
		else
			f = f->next
		end if
	wend

	'' There should always be at least 1 file left to emit
	assert( files->head )

	'' Normally, each .bi file should be generated just next to the
	'' corresponding .h file (or one of them in case of merging...).
	'' In that case no directories need to be created.
	''
	'' If an output directory was given, then all .bi files should be
	'' emitted there. This might require creating some sub-directories to
	'' preserve the original directory structure.
	''     commonparent/a.bi
	''     commonparent/foo/a.bi
	''     commonparent/foo/b.bi
	'' shouldn't just become:
	''     outdir/a.bi
	''     outdir/a.bi
	''     outdir/b.bi
	'' because a.bi would be overwritten and the foo/ sub-directory would
	'' be lost. Instead, it should be:
	''     outdir/a.bi
	''     outdir/foo/a.bi
	''     outdir/foo/b.bi
	if( pre->outdir ) then
		var f = files->head
		var commonparent = pathOnly( *f->text )
		f = f->next
		while( f )
			commonparent = pathFindCommonBase( commonparent, *f->text )
			f = f->next
		wend
		if( verbose ) then
			print "common parent: " + commonparent
		end if

		f = files->head
		do
			'' Remove the common parent prefix
			var normed = *f->text
			assert( strStartsWith( normed, commonparent ) )
			normed = right( normed, len( normed ) - len( commonparent ) )

			'' And prefix the output dir instead
			normed = pathAddDiv( *pre->outdir ) + normed

			astSetText( f, normed )
			astSetComment( f, normed )

			f = f->next
		loop while( f )
	end if

	f = files->head
	do
		'' Replace the file extension, .h -> .bi
		astSetText( f, pathStripExt( *f->text ) + ".bi" )
		f = f->next
	loop while( f )

	f = files->head
	do
		print "emitting: " + *f->text

		'' Do auto-formatting if not preserving whitespace
		if( (pre->options and PRESETOPT_WHITESPACE) = 0 ) then
			astAutoAddDividers( f->expr )
		end if

		'astDump( f->expr )
		emitFile( *f->text, f->expr )

		f = f->next
	loop while( f )

	astDelete( files )
	astDelete( versions )
	astDelete( targetversions )

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

	filesysInit( )

	if( __FB_ARGC__ = 1 ) then
		hPrintHelp( "" )
	end if

	'' Input files and various other info from command line
	dim cmdline as FROGPRESET
	presetInit( @cmdline )

	'' *.fbfrog files from command line
	var presetfiles = astNewGROUP( )

	for i as integer = 1 to __FB_ARGC__-1
		var arg = *__FB_ARGV__[i]

		'' option?
		if( left( arg, 1 ) = "-" ) then
			'' Strip all preceding '-'s
			do
				arg = right( arg, len( arg ) - 1 )
			loop while( left( arg, 1 ) = "-" )

			select case( arg )
			case "h", "?", "help", "version"
				hPrintHelp( "" )
			case "w"
				cmdline.options or= PRESETOPT_WHITESPACE
			case "nomerge"
				cmdline.options or= PRESETOPT_NOMERGE
			case "o"
				i += 1
				if( i >= __FB_ARGC__ ) then
					hPrintHelp( "missing output directory path for -o" )
				end if
				cmdline.outdir = strDuplicate( __FB_ARGV__[i] )
			case "v", "verbose"
				verbose = TRUE
			case else
				hPrintHelp( "unknown option: " + *__FB_ARGV__[i] )
			end select
		else
			if( hReadableDirExists( arg ) ) then
				'' Search input directory for *.fbfrog files, if none found,
				'' add it for *.h search later
				var foundfiles = hScanDirectory( arg, "*.fbfrog" )
				if( foundfiles->head ) then
					astAppend( presetfiles, foundfiles )
				else
					astAppend( cmdline.code, astNew( ASTCLASS_DIR, arg ) )
				end if
			elseif( pathExtOnly( arg ) = "fbfrog" ) then
				astAppend( presetfiles, astNewTEXT( arg ) )
			else
				astAppend( cmdline.code, astNew( ASTCLASS_FILE, arg ) )
			end if
		end if
	next

	'' If *.fbfrog files were given, work them off one by one
	var presetfile = presetfiles->head
	if( presetfile ) then
		'' For each *.fbfrog file...
		do
			var presetfilename = *presetfile->text
			print "+" + string( len( presetfilename ) + 2, "-" ) + "+"
			print "| " + presetfilename + " |"
			print "+" + string( len( presetfilename ) + 2, "-" ) + "+"

			'' Read in the *.fbfrog preset
			dim as FROGPRESET pre
			presetInit( @pre )
			presetParse( @pre, presetfilename )

			'' The preset's input files are given relative to the preset's directory
			var presetdir = pathAddDiv( pathOnly( presetfilename ) )

			'' Allow overriding the preset's input files with those
			'' from the command line
			if( presetHasInputFiles( @cmdline ) ) then
				presetOverrideInputFiles( @pre, @cmdline )
				'' Also, then we'll rely on the paths from command line,
				'' and no preset specific directory can be prefixed.
				presetdir = ""
			end if

			if( cmdline.outdir ) then
				assert( pre.outdir = NULL )
				pre.outdir = strDuplicate( cmdline.outdir )
			end if

			frogWorkPreset( @pre, presetfilename, presetdir )
			presetEnd( @pre )

			presetfile = presetfile->next
		loop while( presetfile )
	else
		'' Otherwise just work off the input files and options given
		'' on the command line, it's basically a "preset" too, just not
		'' stored in a *.fbfrog file but given through command line
		'' options.
		frogWorkPreset( @cmdline, "", "" )
	end if

	if( verbose ) then
		astPrintStats( )
	end if
