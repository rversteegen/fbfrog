#ifndef TEST_H
#define TEST_H

#ifdef __cplusplus
extern _
"C"              '' oh look, this is on a new line!
#endif

type T 
	/' TODO: token 93 '/ i: /' TODO: token 93 '/ j
	/' TODO: token 93 '/ *(*p)(/' TODO: token 93 '/*)
end type

/' TODO: token 105 '/ /' TODO: token 103 '/ T TT

/' TODO: token 103 '/ TTT

/' TODO: token 105 '/ type 
	/' TODO: token 93 '/ a
	double x
end type TTTT

enum 
	A = &o               /' This is A '/
	B, C = (1 shl 4)     /' This is B and C '/
	D                    /' This is D '/
end enum

/' sub '/
/' TODO: token 109 '/ f01()

/' function as any ptr '/
/' TODO: token 109 '/ *f02()

/' taking an int, returning an int '/
/' TODO: token 93 '/ f03(/' TODO: token 93 '/)

/' some more params, and even ellipsis '/
/' TODO: token 93 '/ *f04(/' TODO: token 93 '/ x, short y, /' TODO: token 72 '/ *z, ...)

/' typedef '/
TT *f05()

/' struct '/
/' TODO: token 103 '/ T f06(/' TODO: token 103 '/ T *, TT ******)

#define MY_EXTERN /'__declspec(dllexport)'/
#define MY_CALL __attribute__((__stdcall__))/'__stdcall'/

/' some #defines in front, as is pretty common '/
MY_EXTERN MY_CALL TT f07()

/' wrapped '/
/' TODO: token 93 '/ f08(/' TODO: token 93 '/ a, /' TODO: token 93 '/ b,
        /' TODO: token 93 '/ c, /' TODO: token 93 '/ d)

/' sub ptr '/
/' TODO: token 109 '/ (*fp01)()

/' function pointer, with function pointer param '/
double *(*fpo02)(/' TODO: token 93 '/ ***(*)(/' TODO: token 72 '/**))

/' PP expressions '/
#if (/' TODO: token 18 '/defined(FOO_BAR) andalso THIS_IS_INSANE >= 123) _
    orelse (OH_MAN_WHATS_THE_PRECEDENCE < 5 andalso (defined(OK) _
                                            orelse defined(I_DONT_KNOW)))
	#define PPMERGE(a, b) a##b
	#define PPSTRINGIZE(a) #a
	/' TODO: token 105 '/ /' TODO: token 108 '/ __int8 uint8_t
	/' TODO: token 105 '/ /' TODO: token 108 '/ __int32 uint32_t
	/' TODO: token 105 '/ /' TODO: token 108 '/ __int64 uint64_t

#	if X = 4294967295UL orelse X = &o.1e+1
#		define HOORAY
#	endif
#endif

#ifdef __cplusplus
end extern
#endif

#endif