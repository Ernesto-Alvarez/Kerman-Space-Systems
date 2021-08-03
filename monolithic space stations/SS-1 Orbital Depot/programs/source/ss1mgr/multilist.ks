//Constructor: return empty multilist

GLOBAL FUNCTION multilist
{
	PARAMETER columns.
	LOCAL newML IS lexicon().
	SET newML["typeId"] TO "KSS-Multilist".
	SET newML["data"] TO list().
	SET newML["columnKeys"] TO columns.
	SET newML["offsets"] TO lexicon().

	FROM { SET i to 0. } UNTIL i = newML["columnKeys"]:LENGTH STEP { SET i TO i+1. } DO 
	{
		newML["offsets"]:ADD(newML["columnKeys"][i],i).
	}
	return newML.
}

GLOBAL FUNCTION MLadd
{
	PARAMETER self.
	PARAMETER input.

	SET offset TO self["data"]:LENGTH.
	self["data"]:ADD(list()).

	FOR i IN self["columnKeys"]
	{
		self["data"][offset]:ADD(input[i]).
	}

}


GLOBAL FUNCTION MLdelete
{
	PARAMETER self.
	PARAMETER index.

	self["data"]:REMOVE(index).

}



GLOBAL FUNCTION MLlength
{
	PARAMETER self.
	
	return self["data"]:LENGTH.

}

GLOBAL FUNCTION MLkeys
{
	PARAMETER self.

	return self["columnKeys"].
}



GLOBAL FUNCTION MLreadCell
{
	PARAMETER self.
	PARAMETER index.
	PARAMETER column.

	SET offset TO self["offsets"][column].

	return MLreadCellNum(self,index,offset).
	
}

GLOBAL FUNCTION MLreadCellNum
{
	PARAMETER self.
	PARAMETER index.
	PARAMETER offset.

	return self["data"][index][offset].	
	
}

GLOBAL FUNCTION MLwriteCell
{
	PARAMETER self.
	PARAMETER index.
	PARAMETER column.
	PARAMETER data.

	SET offset TO self["offsets"][column].

	SET self["data"][index][offset] TO data.
	
}

GLOBAL FUNCTION MLfilterCols
{
	PARAMETER self.
	PARAMETER columns.

	SET retval TO multilist(columns).
	
	FROM { SET i TO 0. } UNTIL i = MLlength(self) STEP { SET i TO i+1. } DO 
	{
		SET data TO lexicon().
		FOR j IN columns
		{
			SET data[j] TO MLreadCell(self,i,j).
		}
		MLadd(retval,data).	
	}
	return retval.
}

GLOBAL FUNCTION MLfilterRows
{
	PARAMETER self.
	PARAMETER column.
	PARAMETER value.

	SET retval TO multilist(self["columnKeys"]).

	FROM { SET i TO 0. } UNTIL i = MLlength(self) STEP { SET i TO i+1. } DO 
	{
		IF MLreadCell(self,i,column) = value
		{
			SET data TO lexicon().
			FOR j IN self["columnKeys"]
			{
				SET data[j] TO MLreadCell(self,i,j).
			}
			MLadd(retval,data).
		}
	}
	return retval.

}
