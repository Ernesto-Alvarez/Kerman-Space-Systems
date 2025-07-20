Kerbal bootloader

The kerbal bootloader (kboot) is a simple self contained bootloader that can be loaded as the default file in a kOS core to load a complex program.
The bootloader has the following responsibilities:
	To put the system in a known state
	To check whether the software is present or not
	To download the software from the archive if it is not present
	To run the software

The data about the program is stored as local variables. This means that for every program to run, a modified copy of the bootloader is necessary. This is a limitation of kOS, as only a single file can be provided to the kOS core. To counter this, the bootloader is as generic as possible and the only required changes are in the configuration variables themselves.

The kerbal bootloader is divided into blocks. These blocks can be removed to save disk space if the function provided is not needed.

**Archive structure**

The archive is structured in a specific way to use the kerbal bootloader. There are two required directories, plus an optional one.

The /boot directory contains all bootloaders. This is a limitation imposed by kOS, because it is where the boot file to be assigned to a kOS core resides. This directory should contain all configured kboot images to be used, under different names. The naming system is not important, as long as the proper bootloader pointing to the correct firmware is known.

The /firmware directory contains the different programs to be uploaded to the different cores. Each program should reside in its own directory. The name of the directory defines the name of the program. This subdirectory is to be copied at boot time to the core's storage. The files in the firmware should be exactly as needed by the device using them.

The /source directory is an optional directory containing the source code for each program. This directory is not referenced by kboot. The difference between this directory and /firmware is that /source should contain the original kerboscript files, while /firmware may contain compiled versions instead to reduce file size. Having the source directory adds a trusted repository of the original files to reconstruct /firmware if necessary.

**Bootloader sections**

The variables are stored at the beginning of the file. They are used to configure the bootloader. The program name is the same as the directory where the program resides. A kboot compatible program should have its entry point in entrypoint.ks (or entrypoint.ksm), which is run by kboot. However, the name of the entrypoint of the program can be changed to whatever is required.

//VARIABLES
LOCAL programName IS "FILL PROGRAM NAME HERE".
LOCAL entryPoint IS "entrypoint".

The bootloader then sets the computer to a known state. The local volume is selected and the working path is set to the root directory. Tecnically, this section is not needed for a new boot and the section could be removed without adverse effects. However, the state is set because it is possible for an operator to abort the running program and then invoke kboot to reset the computer. Having a switch to a known state allows the operator to call kboot from any directory or volume and still get consistent results.

//INITIAL STATE
print "Setting initial computer state".
SWITCH TO 1.
CD("/").

The bootloader then checks if the entry point is present. If that is the case, it assumes the program is present and skips the download step. If it is not present, it attempts to get the code from the repository. This section can be eliminated if this download capability is not desired. Elimination of this section requires to do a manual download of the whole firmware once.
If the firmware is not present, the bootloader waits until there is a connection to the archive. Once the connection is established, it copies the firmware directory to the local volume. 

//DOWNLOAD FIRMWARE
print "Checking if firmware is present".
IF NOT EXISTS("/" + programName + "/" + entryPoint)
	{
	print "Firmware not present in local storage".
	print "Attempting to contact archive".
	WAIT UNTIL HOMECONNECTION:ISCONNECTED.
	print "Connection to archive established".
	print "Loading firmware from archive".
	COPYPATH("0:/firmware/" + programName,"/").
	IF NOT EXISTS("/" + programName + "/" + entryPoint)
		{
		print "Unable to load firmware from archive".	
		}
	}

Finally, once the firmware is loaded, it executes the firmware. Note that, as of now, there is no integrity check. An aborted firmware transfer may result in an unusable system. To recover from that situation, manually delete the firmware path (at least delete the application's entry point to force kboot to do a new transfer).

**Design notes**

The bootloader does not accept any user input nor can wait for anything except possibly a connection for the download. A kOS core may reset at any time (e.g. when a ship goes on rails). Any program (including the bootloader) must be able to recover from a complete loss of state, either by being stateless or by reloading the state from storage. Any wait by the bootloader would interrupt the normal program flow, interrupting potentially critical functions while the bootloader is waiting for any reason. While the bootloader waits for a connection while attempting to download a firmware image, there is not problem because the software would not be operational until the download is complete.

The firmware resides in its own directory. The idea is that its design can be independent of the bootloader. The bootloader does not presume anything about the software, except that an entry point must be present.

The download operation is included in the bootloader because only the bootloader is loaded by KSP. Either the program would be monolithic in the boot file (obviating the need for a bootloader) or the bootloader would need to transfer the firmware from the archive (explaining the download capability).

//EXECUTE
print "Executing firmware".
CD(programName).
RUNPATH(entryPoint).