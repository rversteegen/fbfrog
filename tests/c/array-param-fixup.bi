#pragma once

extern "C"

declare sub f(byval i as long ptr)

extern p as sub(byval i as long ptr)

declare sub f(byval p as sub(byval i as long ptr))

type UDT
	declare sub f(byval i as long ptr)

	p as sub(byval i as long ptr)
end type

#define A cptr(sub cdecl(byval i as long ptr), 0)

type C
	i as long
end type

type UDT2
	p as sub(byval x as C ptr)
end type

end extern
