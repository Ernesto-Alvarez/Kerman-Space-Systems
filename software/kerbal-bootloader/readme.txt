Kerbal bootloader

The kerbal bootloader (kboot) is a simple self contained bootloader that can be loaded as the default file in a kOS core to load a complex program.
The bootloader has the following responsibilities:
	To put the system in a known state
	To check whether the software is present or not
	To download the software from the archive if it is not present
	To run the software

The data about the program is stored as local variables. This means that for every program to run, a modified copy of the bootloader is necessary. This is a limitation of kOS, as only a single file can be provided to the kOS core. To counter this, the bootloader is as generic as possible and the only required changes are in the configuration variables themselves.

The kerbal bootloader is divided into blocks. These blocks can be removed to save disk space if the function provided is not needed.