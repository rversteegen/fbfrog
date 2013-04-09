'' Token emitter

#include once "fbfrog.bi"

declare sub emitDecl _
	( _
		byref x as integer, _
		byref ln as string, _
		byval decl as integer, _
		byval belongs_to_dimshared as integer = FALSE _
	)
declare function emitTk( byval x as integer ) as integer

type EmitterStuff
	fo		as integer '' Output file
	indentlevel	as integer

	todocount	as integer
	filecount	as integer
end type

dim shared as EmitterStuff stuff

private sub emitInit( byref filename as string )
	stuff.indentlevel = 0
	stuff.fo = freefile( )
	if( open( filename, for binary, access write, as #stuff.fo ) ) then
		oops( "could not open output file: '" + filename + "'" )
	end if
end sub

private sub emitEnd( )
	close #stuff.fo
	stuff.fo = 0
	stuff.filecount += 1
end sub

private sub emit( byval text as zstring ptr )
	dim as integer length = any
	length = len( *text )
	if( put( #stuff.fo, , *cptr( ubyte ptr, text ), length ) ) then
		oops( "file I/O failed" )
	end if
end sub

private sub emitEol( )
	#if defined( __FB_WIN32__ ) or defined( __FB_DOS__ )
		emit( !"\r\n" )
	#else
		emit( !"\n" )
	#endif
end sub

private sub emitIndent( )
	stuff.indentlevel += 1
end sub

private sub emitUnindent( )
	stuff.indentlevel -= 1
end sub

private sub emitStmtBegin( byref ln as string )
	for i as integer = 1 to stuff.indentlevel
		emit( !"\t" )
	next
	emit( ln )
end sub

private sub emitStmt( byref ln as string )
	emitStmtBegin( ln )
	emitEol( )
end sub

function emitType( byval x as integer ) as string
	static as zstring ptr types(0 to TYPE__COUNT-1) = _
	{ _
		NULL       , _
		@"any"     , _
		@"byte"    , _
		@"ubyte"   , _
		@"zstring" , _
		@"short"   , _
		@"ushort"  , _
		@"long"    , _
		@"ulong"   , _
		@"longint" , _
		@"ulongint", _
		@"single"  , _
		@"double"  , _
		NULL         _
	}

	dim as string s
	dim as integer dtype = any

	dtype = tkGetType( x )

	if( typeIsConstAt( dtype, 0 ) ) then
		s += "const "
	end if

	if( typeGetDt( dtype ) = TYPE_UDT ) then
		s += *tkGetSubtype( x )
	else
		s += *types(typeGetDt( dtype ))
	end if

	for i as integer = 1 to typeGetPtrCount( dtype )
		if( typeIsConstAt( dtype, i ) ) then
			s += " const"
		end if

		s += " ptr"
	next

	function = s
end function

private function emitSubOrFunction( byval x as integer ) as string
	if( tkGetType( x ) = TYPE_ANY ) then
		function = "sub"
	else
		function = "function"
	end if
end function

private sub emitParamListAndResultType( byref x as integer, byref ln as string )
	dim as integer y = any, count = any

	'' The parameter tokens, if any, are following behind the main token,
	'' grouped in a BEGIN/END:
	''    TK_PROC/...
	''    TK_BEGIN
	''        TK_PARAM
	''        ...
	''    TK_END

	ln += "("

	y = x + 1
	if( tkGet( y ) = TK_BEGIN ) then
		'' Begin
		y += 1

		count = 0
		while( tkGet( y ) <> TK_END )
			if( count > 0 ) then
				ln += ","
			end if
			ln += " "

			if( tkGet( y ) = TK_PARAMVARARG ) then
				ln += "..."
				y += 1
			else
				emitDecl( y, ln, TK_PARAM )
			end if

			count += 1
		wend

		'' End
		y += 1
	end if

	ln += " )"

	'' Function result type
	if( tkGetType( x ) <> TYPE_ANY ) then
		ln += " as " + emitType( x )
	end if

	'' Skip over the main token and its parameters, if any
	x = y
end sub

private sub emitDecl _
	( _
		byref x as integer, _
		byref ln as string, _
		byval decl as integer, _
		byval belongs_to_dimshared as integer _
	)

	dim as zstring ptr s = any

	select case( decl )
	case TK_GLOBAL
		ln += "dim shared "
	case TK_EXTERNGLOBAL
		ln += "extern "
		if( belongs_to_dimshared ) then
			ln += "    "
		end if
	case TK_PARAM
		ln += "byval "
	case TK_FIELD

	case else
		assert( FALSE )
	end select

	s = tkGetText( x )
	if( len( *s ) > 0 ) then
		ln += *s + " "
	end if

	ln += "as "

	if( tkIsProcPtr( x ) ) then
		ln += emitSubOrFunction( x )
		emitParamListAndResultType( x, ln )
	else
		ln += emitType( x )
		x += 1
	end if
end sub

private sub emitTodo( byval x as integer )
	dim as string ln
	dim as zstring ptr s = any

	ln = "'' "

	if( tkHasSourceLocation( x + 1 ) ) then
		ln += *tkGetSourceFile( x + 1 )
		ln += "(" & tkGetLineNum( x + 1 ) + 1 & "): "
	end if

	ln += "TODO"

	s = tkGetText( x )
	if( len( *s ) > 0 ) then
		ln += ": " + *s
	end if

	emitStmt( ln )
	stuff.todocount += 1
end sub

private function emitTk( byval x as integer ) as integer
	dim as string ln
	dim as integer y = any
	dim as zstring ptr s = any

	assert( tkGet( x ) <> TK_EOF )
	assert( tkGet( x ) <> TK_BEGIN )
	assert( tkGet( x ) <> TK_END )

	select case as const( tkGet( x ) )
	case TK_NOP
		x += 1

	case TK_PPINCLUDE
		emitStmt( "#include """ + *tkGetText( x ) + """" )
		x += 1

	case TK_PPDEFINE
		emitStmtBegin( "#define " + *tkGetText( x ) )

		'' PPDefine
		x += 1

		'' Begin?
		if( tkGet( x ) = TK_BEGIN ) then
			x += 1

			while( tkGet( x ) <> TK_END )
				x = emitTk( x )
			wend

			'' End
			x += 1
		end if

		emitEol( )

	case TK_STRUCT
		ln = "type"
		s = tkGetText( x )
		if( len( *s ) > 0 ) then
			ln += " " + *s
		end if
		emitStmt( ln )

		'' Struct
		x += 1

		'' Begin
		assert( tkGet( x ) = TK_BEGIN )
		x += 1

		emitIndent( )
		while( tkGet( x ) <> TK_END )
			x = emitTk( x )
		wend
		emitUnindent( )

		'' End
		x += 1

		emitStmt( "end type" )

	case TK_FIELD, TK_FIELDPROCPTR
		emitDecl( x, ln, TK_FIELD )
		emitStmt( ln )

	case TK_GLOBAL, TK_GLOBALPROCPTR
		y = x
		emitDecl( x, ln, TK_EXTERNGLOBAL, TRUE )
		emitStmt( ln )

		x = y
		ln = ""
		emitDecl( x, ln, TK_GLOBAL )
		emitStmt( ln )

	case TK_EXTERNGLOBAL, TK_EXTERNGLOBALPROCPTR
		emitDecl( x, ln, TK_EXTERNGLOBAL )
		emitStmt( ln )

	case TK_STATICGLOBAL, TK_STATICGLOBALPROCPTR
		emitDecl( x, ln, TK_GLOBAL )
		emitStmt( ln )

	case TK_PROC
		ln = "declare "
		ln += emitSubOrFunction( x )
		ln += " "
		ln += *tkGetText( x )
		emitParamListAndResultType( x, ln )
		emitStmt( ln )

	case TK_EOL, TK_DIVIDER
		emitEol( )
		x += 1

	case TK_TODO
		emitTodo( x )
		x += 1

		'' Begin?
		if( tkGet( x ) = TK_BEGIN ) then
			x += 1

			while( tkGet( x ) <> TK_END )
				x = emitTk( x )
			wend

			'' End
			x += 1
		end if

	case TK_COMMENT
		emit( "/'" )
		emit( tkGetText( x ) )
		emit( "'/" )
		x += 1

	case TK_LINECOMMENT
		emit( "''" )
		emit( tkGetText( x ) )
		x += 1

	case TK_DECNUM
		emit( tkGetText( x ) )
		x += 1

	case TK_HEXNUM
		emit( "&h" )
		emit( ucase( *tkGetText( x ) ) )
		x += 1

	case TK_OCTNUM
		emit( "&o" )
		emit( tkGetText( x ) )
		x += 1

	case TK_STRING
		emit( """" )
		emit( tkGetText( x ) )
		emit( """" )
		x += 1

	case TK_WSTRING
		emit( "wstr( """ )
		emit( tkGetText( x ) )
		emit( """ )" )
		x += 1

	case TK_ESTRING
		emit( "!""" )
		emit( tkGetText( x ) )
		emit( """" )
		x += 1

	case TK_EWSTRING
		emit( "wstr( !""" )
		emit( tkGetText( x ) )
		emit( """ )" )
		x += 1

	case else
		emit( tkGetText( x ) )
		x += 1

	end select

	function = x
end function

sub emitWriteFile( byref filename as string )
	dim as integer x = any

	emitInit( filename )

	x = 0
	while( tkGet( x ) <> TK_EOF )
		x = emitTk( x )
	wend

	emitEnd( )
end sub

sub emitStats( )
	dim as string message

	message = stuff.todocount & " TODO"
	if( stuff.todocount <> 1 ) then
		message += "s"
	end if
	message += " in " & stuff.filecount & " file"
	if( stuff.filecount <> 1 ) then
		message += "s"
	end if

	print message
end sub
