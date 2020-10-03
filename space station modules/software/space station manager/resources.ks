@LazyGlobal off.

RUNONCEPATH("basefacilities").
RUNONCEPATH("functionregistry").

LOCAL resourceParts is lexicon().
LOCAL resourceAmounts is lexicon().
LOCAL resourceCapacities is lexicon().


GLOBAL FUNCTION enumerateResources
{

	//FOR EACH BLOCK
	FROM { LOCAL i IS 0. } UNTIL i = getNumberofBlocks() STEP { SET i TO i+1. } DO
	{
		//FOR EACH PART
		FOR j in getBlockParts(i)
		{
			//Take note of each resource
			FOR k IN j:RESOURCES
			{
				IF NOT resourceParts:KEYS:CONTAINS(k:NAME)
				{
					SET resourceParts[k:NAME] TO list().
					SET resourceAmounts[k:NAME] TO 0.
					SET resourceCapacities[k:NAME] TO 0.
				}
				resourceParts[k:NAME]:ADD(k).
				SET resourceAmounts[k:NAME] TO resourceAmounts[k:NAME]+k:AMOUNT.
				SET resourceCapacities[k:NAME] TO resourceCapacities[k:NAME]+k:CAPACITY.
			}
		}
	
	}
	for i in resourceCapacities:KEYS
	{
		print i + ": " + resourceAmounts[i] + "/" + resourceCapacities[i].
	}
}

registerFunction(enumerateResources@,"Resources","enumerateResources","List base resources").