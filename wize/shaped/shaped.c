/*
Tk window manager miscellaneous extensions

(C) Copyright 2005, Rildo Pragana <rildo@pragana.net>

The authors hereby grant permission to use, copy, modify, distribute,
    and license this software and its documentation for any purpose, provided
    that existing copyright notices are retained in all copies and that this
    notice is included verbatim in any distributions. No written agreement,
    license, or royalty fee is required for any of the authorized uses.
    Modifications to this software may be copyrighted by their authors
    and need not follow the licensing terms described here, provided that
    the new terms are clearly indicated on the first page of each file where
    they apply.

    IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
    FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
    ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
    DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
    THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
    IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
    NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
    MODIFICATIONS.

    GOVERNMENT USE: If you are acquiring this software on behalf of the
    U.S. government, the Government shall have only "Restricted Rights"
    in the software and related documentation as defined in the Federal
    Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
    are acquiring the software on behalf of the Department of Defense, the
    software shall be classified as "Commercial Computer Software" and the
    Government shall have only "Restricted Rights" as defined in Clause
    252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
    authors grant the U.S. Government and others acting in its behalf
    permission to use and distribute the software in accordance with the
    terms specified in this license.
    */

#ifdef __WIN32__
#include "winshaped.c"
#else

    #include <unistd.h>
    #include <X11/X.h>
    #include <X11/Xlib.h>
    #include <X11/Xatom.h>
    #include <X11/Xutil.h>
    #include <X11/Xmd.h>
    #include <X11/extensions/shape.h>
    #include <X11/cursorfont.h>
    #include <X11/xpm.h>

    #include <tcl.h>
    #include <tk.h>

    /*static Display *dpy;
    static Window rootw;
    static int screen_number;
    static Screen *screen;
    static unsigned long rmask;
    static Atom wm_activewin; */

    /* MWM decorations values */
    #define MWM_DECOR_NONE          0
    #define MWM_DECOR_ALL           (1L << 0)
    #define MWM_DECOR_BORDER        (1L << 1)
    #define MWM_DECOR_RESIZEH       (1L << 2)
    #define MWM_DECOR_TITLE         (1L << 3)
    #define MWM_DECOR_MENU          (1L << 4)
    #define MWM_DECOR_MINIMIZE      (1L << 5)
    #define MWM_DECOR_MAXIMIZE      (1L << 6)

    /* KDE decoration values */
    enum {
    KDE_noDecoration = 0,
        KDE_normalDecoration = 1,
        KDE_tinyDecoration = 2,
        KDE_noFocus = 256,
        KDE_standaloneMenuBar = 512,
        KDE_desktopIcon = 1024 ,
        KDE_staysOnTop = 2048
};

int errorHandler(Display *dpylay, XErrorEvent *err) {
    /* ignore all errors */
}

void wm_decorations(Tcl_Interp *interp, Window window, int on) {
    Atom WM_HINTS;
    Tk_Window tkwin = Tk_MainWindow(interp);
    Display *dpy = Tk_Display(tkwin);
    int screen_number = Tk_ScreenNumber(tkwin);
    Screen *screen = ScreenOfDisplay(dpy,screen_number);
    Window rootw;
    
    if (ScreenCount(dpy)) {
        rootw = RootWindow(dpy,screen_number);
    }

    WM_HINTS = XInternAtom(dpy, "_MOTIF_WM_HINTS", True);
    if ( WM_HINTS != None ) {
        #define MWM_HINTS_DECORATIONS   (1L << 1)
        struct {
            unsigned long flags;
            unsigned long functions;
            unsigned long decorations;
            long input_mode;
            unsigned long status;
        } MWMHints = { MWM_HINTS_DECORATIONS, 0,
            MWM_DECOR_NONE, 0, on };
            XChangeProperty(dpy, window, WM_HINTS, WM_HINTS, 32,
            PropModeReplace, (unsigned char *)&MWMHints,
            sizeof(MWMHints)/4);
    }
    WM_HINTS = XInternAtom(dpy, "KWM_WIN_DECORATION", True);
    if ( WM_HINTS != None ) {
        long KWMHints = (on ? KDE_normalDecoration : KDE_tinyDecoration);
        XChangeProperty(dpy, window, WM_HINTS, WM_HINTS, 32,
            PropModeReplace, (unsigned char *)&KWMHints,
            sizeof(KWMHints)/4);
    }

    WM_HINTS = XInternAtom(dpy, "_WIN_HINTS", True);
    if ( WM_HINTS != None ) {
        long GNOMEHints = on;
        XChangeProperty(dpy, window, WM_HINTS, WM_HINTS, 32,
            PropModeReplace, (unsigned char *)&GNOMEHints,
            sizeof(GNOMEHints)/4);
    }
    WM_HINTS = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", True);
    if ( WM_HINTS != None ) {
        Atom NET_WMHints[2];
        NET_WMHints[0] = XInternAtom(dpy,
            "_KDE_NET_WM_WINDOW_TYPE_OVERRIDE", True);
            NET_WMHints[1] = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_NORMAL", True);
            XChangeProperty(dpy, window,
            WM_HINTS, XA_ATOM, 32, PropModeReplace,
            (unsigned char *)&NET_WMHints, 2);
    }
    XSetTransientForHint(dpy, window, rootw);
    XUnmapWindow(dpy, window);
    XMapWindow(dpy, window);
}

#if 0
int initXwmhandler( ClientData client_data, Tcl_Interp *interp, int objc,
    Tcl_Obj * CONST objv[]) {
        Tk_Window tkwin;

        tkwin = Tk_MainWindow(interp);
        dpy = Tk_Display(tkwin);
        screen_number = Tk_ScreenNumber(tkwin);
        screen = ScreenOfDisplay(dpy,screen_number);
        rootw = RootWindow(dpy,screen_number);
        wm_activewin = XInternAtom(dpy,"_NET_ACTIVE_WINDOW",False);
        return TCL_OK;
}
#endif


int setXwinshape(ClientData client_data, Tcl_Interp *interp, int objc,
    Tcl_Obj * CONST objv[]) {
        Window w;
        char *wpath;
        Pixmap pixmap, mask = None;
        XEvent ev;
        Tk_Window subwin, tkwin = Tk_MainWindow(interp);
        Window *children;
        int nchildren;
        Window dummy,parent;
        char *imageName;
        Tk_PhotoHandle handle;
        Region region;

        Tk_Window ttkwin = Tk_MainWindow(interp);
        Display *dpy = Tk_Display(ttkwin);
        int screen_number = Tk_ScreenNumber(ttkwin);
        Screen *screen = ScreenOfDisplay(dpy,screen_number);
        Window rootw;
	if (ScreenCount(dpy)) {
           rootw = RootWindow(dpy,screen_number);
        }

    /* initXwmhandler(0,interp,0,NULL); */

    if (objc != 3 && objc != 2) {
        Tcl_WrongNumArgs(interp,1,objv,"window ?image?");
        return TCL_ERROR;
    }

    wpath = Tcl_GetStringFromObj(objv[1], NULL);
    Tk_MakeWindowExist(tkwin);
    subwin = Tk_NameToWindow(interp,wpath,tkwin);
    Tk_MakeWindowExist(subwin);
    if (!Tk_IsMapped(subwin)) {
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "window is not mapped", 0);
        return TCL_ERROR;
    }

    XQueryTree(dpy,Tk_WindowId(Tk_NameToWindow(interp,wpath,tkwin)),
        &dummy,&w,&children,&nchildren);
    if (objc == 2) {
	int cnt, ord;
	Region clipRegion = XCreateRegion();
	XRectangle *old, all = {0, 0 };
	all.width = Tk_Width(subwin);
	all.height = Tk_Height(subwin);
        old = XShapeGetRectangles(dpy, w, ShapeBounding, &cnt, &ord);
	if (old != NULL) {
            XShapeCombineRectangles(dpy, w, ShapeBounding, 0, 0, old, cnt, ShapeSubtract, ord);
	}
	XUnionRectWithRegion(&all, clipRegion, clipRegion);
        XShapeCombineRegion(dpy, w, ShapeBounding, 0, 0, clipRegion, ShapeSet);
	XDestroyRegion(clipRegion);
        wm_decorations(interp, w, 1);

    } else {
	imageName = Tcl_GetString(objv[2]);
        handle = Tk_FindPhoto(interp, imageName);
        if (handle == NULL) {
            mask = Tk_GetBitmap(interp, tkwin, Tk_GetUid(imageName));
            if (mask == None) {
                return TCL_ERROR;
            }
        } else {
            region = (Region)TkPhotoGetValidRegion(handle);
            if (region == None) {
                Tcl_AppendResult(interp, "bad transparency info in photo image ",
                    imageName, NULL);
                return TCL_ERROR;
            }
        }

        wm_decorations(interp, w, 0);

        if (mask != None) {
            XShapeCombineMask(dpy, w, ShapeBounding, 0, 0, mask, ShapeSet);
        } else {
            XShapeCombineRegion(dpy, w, ShapeBounding, 0, 0, region, ShapeSet);
        }
    }

    if (ScreenCount(dpy)) {
        rootw = RootWindow(dpy,screen_number);
    }
    XSetTransientForHint(dpy, w, rootw);
    XUnmapWindow(dpy, w);
    XMapWindow(dpy, w);
    XSync(dpy, False);
    if (mask != None) {
        Tk_FreeBitmap(dpy, mask);
    }
    return TCL_OK;
}


EXTERN
int Shaped_Init(Tcl_Interp *interp) {

    //XSetErrorHandler(errorHandler);

    Tcl_CreateObjCommand(interp,"::tk::shaped", setXwinshape,
        (ClientData)NULL,(Tcl_CmdDeleteProc *)NULL);
    Tcl_PkgProvide(interp, "Shaped", "0.1");

    return TCL_OK;
}

EXTERN
int Shaped_SafeInit(Tcl_Interp *interp) {
    return Shaped_Init(interp);
}

#endif
