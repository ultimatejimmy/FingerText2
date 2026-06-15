//This file is part of FingerText, a notepad++ snippet plugin.
//
//FingerText is released under MIT License.
//
//MIT license
//
//Copyright (C) 2011 by Tom Lam
//
//Permission is hereby granted, free of charge, to any person
//obtaining a copy of this software and associated documentation
//files (the "Software"), to deal in the Software without
//restriction, including without limitation the rights to use,
//copy, modify, merge, publish, distribute, sublicense, and/or
//sell copies of the Software, and to permit persons to whom the
//Software is furnished to do so, subject to the following
//conditions:
//
//The above copyright notice and this permission notice shall be
//included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//DEALINGS IN THE SOFTWARE.

#include "PluginDefinition.h"
#include "AboutDialog.h"
#include "Version.h"

void AboutDlg::doDialog()
{
	if (!isCreated())
	{
		create(IDD_ABOUT_DLG);
	}
	goToCenter();
}

INT_PTR CALLBACK AboutDlg::run_dlgProc(UINT message, WPARAM wParam, LPARAM lParam)
{
	switch (message)
	{
		case WM_INITDIALOG:
		{
			TCHAR titleBuf[128];
			_stprintf_s(titleBuf, _countof(titleBuf), TEXT("%s %s%s%s"),
				TEXT(PLUGIN_NAME), TEXT(VERSION_TEXT), TEXT(VERSION_STAGE), TEXT(VERSION_STAGE_ADD));
			SetDlgItemText(_hSelf, IDC_ABOUT_TITLE, titleBuf);

			SetDlgItemText(_hSelf, IDC_ABOUT_VERSION, TEXT(DATE_TEXT));
			SetDlgItemText(_hSelf, IDC_ABOUT_AUTHOR, TEXT(AUTHOR_NAME));
			SetDlgItemText(_hSelf, IDC_ABOUT_COPYRIGHT, TEXT(COPYRIGHT_TEXT));

			TCHAR linksBuf[512];
			_stprintf_s(linksBuf, _countof(linksBuf), TEXT("%s\r\n%s"),
				TEXT(AUTHOR_TEXT), TEXT(ABOUT_TEXT));
			SetDlgItemText(_hSelf, IDC_ABOUT_LINKS, linksBuf);

			return TRUE;
		}
		case WM_COMMAND:
		{
			switch (wParam)
			{
				case IDOK:
				case IDCANCEL:
					display(false);
					return TRUE;
				default:
					return FALSE;
			}
		}
		default:
			return FALSE;
	}
}
