INCLUDES = -I/usr/X11R6/include -I/usr/local/include
LIBS = -lX11 -lXext -ltcl8.4
LIBPATH =  -L/usr/local/lib -L/usr/X11R6/lib -L/usr/lib
SHLIB_CFLAGS = -fPIC
SHLIB_LD = ld -G -z text
CC = gcc
CXFLAGS=-DSTATIC_BUILD=1
CFLAGS=$(INCLUDES) -O -g

shaped.so: shaped.c
	$(CC) -c $(CFLAGS) ${SHLIB_CFLAGS} shaped.c
	${SHLIB_LD}  $(LIBPATH) $(LIBS) -o shaped.so shaped.o

libshaped.a: shaped.c
	$(CC) -c $(CFLAGS) $(CXFLAGS) shaped.c
	${AR}  rv libshaped.a shaped.o

clean:
	@rm -f *.a *.o *.so

