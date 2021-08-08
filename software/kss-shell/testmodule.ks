@LazyGlobal off.



LOCAL FUNCTION dummy
{
	print "Dummy function called".
	return True.
}

LOCAL FUNCTION dummy2
{
	print "Dummy2 function called".
	return True.
}


registerFunction(mainMenu,dummy@,"Dummy function").
registerFunction(mainMenu,dummy2@,"Dummy function 2").
registerFunction(mainMenu,sm1@,"Submenu #1").
registerFunction(mainMenu,sm2@,"Submenu #2").
registerFunction(mainMenu,sm3@,"Submenu #3").

LOCAL submenu1 IS createMenu("Submenu #1").
LOCAL submenu2 IS createMenu("Submenu #2").
LOCAL submenu3 IS createMenu(list("Submenu #3","Have fun")).

LOCAL FUNCTION sm1
{
	return callMenu(submenu1).
}

LOCAL FUNCTION sm2
{
	return callMenu(submenu2).
}

LOCAL FUNCTION sm3
{
	return callMenu(submenu3).
}

registerFunction(submenu1,dummy@,"Dummy function").
registerFunction(submenu1,dummy2@,"Dummy function 2").

registerFunction(submenu2,dummy@,"Dummy function").
registerFunction(submenu2,dummy2@,"Dummy function 2").

registerFunction(submenu3,dummy@,"Dummy function").
registerFunction(submenu3,dummy2@,"Dummy function 2").