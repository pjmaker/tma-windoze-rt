#include <windows.h>
#include <tcl.h>
#include <tk.h>

static long getcolor (unsigned char *ptr, int offsets[])
{
    DWORD color = RGB (*(ptr + offsets[0]), *(ptr + offsets[1]),
	    *(ptr + offsets[2]));
    return color;
}

static long transparent (unsigned char *ptr, int offsets[])
{
    DWORD color = *(ptr + offsets[3]);
    return color;
}


static void OnExit (ClientData data)
{

}

static int SetWidget (ClientData data, Tcl_Interp *pInterp,
	int objc, Tcl_Obj *const objv [])
{
    HWND hwnd = NULL;

    if (objc < 2 || objc > 3) {
	Tcl_SetResult (pInterp,
		"wrong # args: should be \"tk::shapedwin windowid ?imageid?\"",
		TCL_STATIC);
	return TCL_ERROR;
    }

    if (Tcl_VarEval (pInterp, "winfo id ",
	    Tcl_GetStringFromObj (objv[1], NULL), NULL) == TCL_OK) {
	int iwnd;
		
	if (Tcl_GetIntFromObj (pInterp, Tcl_GetObjResult (pInterp), &iwnd)
		== TCL_OK) {
	    hwnd = (HWND)(iwnd);
	}
    }

    if (hwnd == NULL) {
	Tcl_SetResult (pInterp, "could not access the window handle",
		TCL_STATIC);
	return TCL_ERROR;
    }

    if (objc == 2) {
	SetWindowRgn (hwnd, NULL, TRUE);
	return TCL_OK;
    }

    return SetTkWindowRegion (pInterp, hwnd, objv[2]);
}


static
int SetTopLevel (ClientData data, Tcl_Interp *pInterp,
	int objc, Tcl_Obj *const objv [])
{
    const int classsize = 50;
    int returnval;
    TCHAR myname[classsize];
    HWND hwnd = NULL;


    if (objc < 2 || objc > 3) {
	Tcl_SetResult(pInterp,
		"wrong # args: should be \"settoplevel windowid ?imageid?\"",
		TCL_STATIC);
	return TCL_ERROR;
    }

    if (Tcl_VarEval(pInterp, "winfo id ",
	    Tcl_GetString (objv[1]), NULL) == TCL_OK) {
	int iwnd;

	if (Tcl_GetIntFromObj(pInterp, Tcl_GetObjResult(pInterp), &iwnd)
		== TCL_OK) {
	    hwnd = (HWND)(iwnd);
	}
    }

    if (hwnd == NULL) {
	Tcl_SetResult (pInterp, "could not access the window handle",
		TCL_STATIC);
	return TCL_ERROR;
    }

    while ((returnval = GetClassName (hwnd, myname, classsize))
	    && strcmp (myname, "TkTopLevel")) {
	hwnd = GetParent (hwnd);
    }

    if (returnval == 0) {
	Tcl_SetResult (pInterp, "Could not get the class name of window",
		TCL_STATIC);
	return TCL_ERROR;
    }

    if (objc == 2) {
	SetWindowRgn (hwnd, NULL, TRUE);
	return TCL_OK;
    }

    return SetTkWindowRegion (pInterp, hwnd, objv[2]);
}


#ifdef __WIN32__
#   undef TCL_STORAGE_CLASS     
#   define TCL_STORAGE_CLASS DLLEXPORT
#endif

EXTERN
int Shaped_Init (Tcl_Interp *pInterp)
{
    if (
#ifdef USE_TCL_STUBS
	Tcl_InitStubs(pInterp, "8.0", 0)
#else
	Tcl_PkgRequire(pInterp, "Tcl", "8.0", 0)
#endif
	== NULL) {
	return TCL_ERROR;
    }
    if (
#ifdef USE_TK_STUBS
	Tk_InitStubs(pInterp, "8.0", 0)
#else
	Tcl_PkgRequire(pInterp, "Tk", "8.0", 0)
#endif
	== NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgProvide(pInterp, "Shaped", "0.1") != TCL_OK) {
	return TCL_ERROR;
    }
    Tcl_CreateObjCommand (pInterp, "::tk::shaped",
	    SetTopLevel, NULL, NULL);
    Tcl_CreateObjCommand (pInterp, "::tk::shapedwin",
	    SetWidget, NULL, NULL);
    Tcl_CreateExitHandler (OnExit, NULL);
    return TCL_OK;
}

EXTERN
int Shaped_SafeInit (Tcl_Interp *pInterp)
{
   return Shaped_Init(pInterp);
}

LPRGNDATA CreateRegionData(const int imgsize)
{
    int datasize = sizeof (RGNDATAHEADER) + imgsize*sizeof(RECT);
    BYTE *pData = (BYTE*)ckalloc(sizeof(BYTE)*datasize);
    LPRGNDATA pRgnData = (LPRGNDATA)pData;
    return pRgnData;
}

void DeleteRegionData(LPRGNDATA pRgnData)
{
    BYTE *pdata = (BYTE*)(pRgnData);
    ckfree((char*)pdata);
}


HRGN	AddRegionData (HRGN hOrigin, LPRGNDATA pRgnData,
	const int size)
{
    pRgnData->rdh.nCount = size;
    HRGN hNewRgn = ExtCreateRegion (NULL, size*sizeof(RECT)
	    + sizeof(RGNDATAHEADER), pRgnData);
    if (hOrigin != NULL) {
	if (ERROR == CombineRgn (hNewRgn, hNewRgn, hOrigin, RGN_OR)) {
	    CloseHandle (hNewRgn);
	    return hOrigin;
	}
	CloseHandle (hOrigin);
    }
    return hNewRgn;
}



int SetTkWindowRegion (Tcl_Interp *pInterp, HWND hwnd,
	Tcl_Obj *pPicture)
{
    unsigned char *ptr;
    int nextline;
    int rectcounter = 0;
    const int imgsize = 100; // 100 rectangles at a time

    LPRGNDATA pRgnData;
    LPRECT rects;

    HRGN hPicRegion = NULL;
    int y = 0;
    int x = 0;


    Tk_PhotoHandle photo = Tk_FindPhoto (pInterp,
	    Tcl_GetStringFromObj (pPicture, NULL));
    if (photo == 0) {
	Tcl_SetResult (pInterp, "could not find image", TCL_STATIC);
	Tcl_AppendResult (pInterp, Tcl_GetStringFromObj (pPicture, NULL), NULL);
	return TCL_ERROR;
    }

    Tk_PhotoImageBlock img;
    Tk_PhotoGetImage (photo, &img);

    ptr = img.pixelPtr;
    nextline = img.pitch - img.pixelSize * (img.width);

    pRgnData = CreateRegionData (imgsize);
    rects = (RECT *)(pRgnData->Buffer);

    pRgnData->rdh.dwSize = sizeof (pRgnData->rdh);
    pRgnData->rdh.iType = RDH_RECTANGLES;
    // pRgnData->rdh.nCount = rectcounter;
    pRgnData->rdh.nRgnSize = 0;
    pRgnData->rdh.rcBound.left = pRgnData->rdh.rcBound.top = 0;
    pRgnData->rdh.rcBound.right = img.width - 1;
    pRgnData->rdh.rcBound.bottom = img.height - 1;


    while (y < img.height) {
	DWORD color = transparent (ptr, img.offset);
	if (color != 0) {
	    rects[rectcounter].top = rects[rectcounter].bottom = y;
	    rects[rectcounter].bottom++;
	    rects[rectcounter].right = rects[rectcounter].left = x;
	    rects[rectcounter].right++;
	    rectcounter++;
	    if (rectcounter >= imgsize) {
		hPicRegion = AddRegionData (hPicRegion, pRgnData, rectcounter);
		rectcounter = 0;
	    }
	}
	ptr += img.pixelSize;
	if (++x == img.width) {
	    x = 0;
	    ++y;
	    ptr += nextline;
	}
    }

    if (rectcounter > 0) {
	hPicRegion = AddRegionData (hPicRegion, pRgnData, rectcounter);
	rectcounter = 0;
    }

    SetWindowRgn (hwnd, hPicRegion, TRUE);
    DeleteRegionData (pRgnData);
    return TCL_OK;
}
